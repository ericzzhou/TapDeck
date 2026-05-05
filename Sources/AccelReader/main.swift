/// AccelReader — 读取 Apple Silicon SPU 加速度计 (Bosch BMI286 IMU)
import Foundation
import IOKit
import IOKit.hid

setbuf(stdout, nil)
setbuf(stderr, nil)

if geteuid() == 0 && getuid() != 0 { setuid(0) }
fputs("UID=\(getuid()) EUID=\(geteuid())\n", stderr)

// 全局引用，防止 ARC 释放
var globalDevice: IOHIDDevice?
var globalReportBuffer: UnsafeMutablePointer<UInt8>?

// MARK: - 唤醒 SPU 驱动

func wakeSPUDrivers() {
    let matching = IOServiceMatching("AppleSPUHIDDriver") as NSMutableDictionary
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return }
    defer { IOObjectRelease(iterator) }

    var count = 0
    while case let service = IOIteratorNext(iterator), service != IO_OBJECT_NULL {
        let props: [(String, Int32)] = [
            ("SensorPropertyReportingState", 1),
            ("SensorPropertyPowerState", 1),
            ("ReportInterval", 1000),
        ]
        for (key, value) in props {
            let cfKey = key as CFString
            let cfValue = value as CFNumber
            IORegistryEntrySetCFProperty(service, cfKey, cfValue)
        }
        IOObjectRelease(service)
        count += 1
    }
    fputs("Woke \(count) SPU driver(s)\n", stderr)
}

// MARK: - HID 回调（必须是 @convention(c) 兼容的）

func hidReportCallback(
    _ context: UnsafeMutableRawPointer?,
    _ result: IOReturn,
    _ sender: UnsafeMutableRawPointer?,
    _ type: IOHIDReportType,
    _ reportID: UInt32,
    _ report: UnsafeMutablePointer<UInt8>,
    _ reportLength: CFIndex
) {
    guard reportLength >= 18 else { return }

    func readInt32LE(_ p: UnsafeMutablePointer<UInt8>, _ off: Int) -> Int32 {
        var v: Int32 = 0
        memcpy(&v, p + off, 4)
        return Int32(littleEndian: v)
    }

    let scale: Double = 1.0 / 65536.0
    let x = Double(readInt32LE(report, 6)) * scale
    let y = Double(readInt32LE(report, 10)) * scale
    let z = Double(readInt32LE(report, 14)) * scale
    let amplitude = abs(sqrt(x * x + y * y + z * z) - 1.0)
    print(amplitude)
}

// MARK: - 启动加速度计

func startAccelerometer() -> Bool {
    let matching = IOServiceMatching("AppleSPUHIDDevice") as NSMutableDictionary
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
        fputs("ERROR: IOServiceGetMatchingServices failed\n", stderr)
        return false
    }
    defer { IOObjectRelease(iterator) }

    while case let service = IOIteratorNext(iterator), service != IO_OBJECT_NULL {
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            IOObjectRelease(service)
            continue
        }

        guard let page = dict["PrimaryUsagePage"] as? Int, page == 0xFF00,
              let usage = dict["PrimaryUsage"] as? Int, usage == 3 else {
            IOObjectRelease(service)
            continue
        }

        fputs("Found accelerometer (Usage=\(usage))\n", stderr)

        guard let deviceRef = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
            IOObjectRelease(service)
            continue
        }
        IOObjectRelease(service)

        // 保持强引用
        let device = deviceRef as IOHIDDevice
        globalDevice = device

        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        fputs("IOHIDDeviceOpen: \(openResult)\n", stderr)
        guard openResult == kIOReturnSuccess else {
            fputs("ERROR: IOHIDDeviceOpen failed. Need root.\n", stderr)
            return false
        }

        // Schedule + Register（与 Python 版本相同顺序）
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let bufSize = 4096
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        globalReportBuffer = buf

        IOHIDDeviceRegisterInputReportCallback(device, buf, bufSize, hidReportCallback, nil)

        fputs("READY\n", stderr)
        return true
    }

    fputs("ERROR: Accelerometer not found\n", stderr)
    return false
}

// 执行
wakeSPUDrivers()
guard startAccelerometer() else { exit(1) }
signal(SIGPIPE, SIG_DFL)
CFRunLoopRun()
