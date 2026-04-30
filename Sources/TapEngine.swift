import Foundation
import IOKit
import IOKit.hid

/// 加速度计数据读取 + 拍击检测 + 动作触发
@MainActor
class TapEngine: ObservableObject {
    @Published var isListening = false
    @Published var isMicMuted = false
    @Published var tapCount = 0
    @Published var sensitivity: Double = 0.05 // 越小越灵敏

    private var hidManager: IOHIDManager?
    private var detector = TapDetector()
    private var lastTapTime: Date = .distantPast
    private let cooldown: TimeInterval = 0.75

    func toggle() {
        if isListening {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !isListening else { return }
        guard openAccelerometer() else {
            print("[TapDeck] 无法打开加速度计，请确认以 sudo 运行或授予权限")
            return
        }
        isListening = true
        print("[TapDeck] 开始监听拍击")
    }

    func stop() {
        if let mgr = hidManager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            hidManager = nil
        }
        isListening = false
        print("[TapDeck] 停止监听")
    }

    // MARK: - IOKit HID 加速度计

    /// 打开 Apple SPU HID 加速度计
    private func openAccelerometer() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // 匹配 Apple SPU HID 传感器（加速度计）
        let matchDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: 0x20,  // Sensor
            kIOHIDDeviceUsageKey as String: 0x73,      // Accelerometer 3D
        ]
        IOHIDManagerSetDeviceMatching(manager, matchDict as CFDictionary)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            print("[TapDeck] IOHIDManagerOpen 失败: \(result)")
            return false
        }

        // 获取匹配的设备
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = deviceSet.first else {
            print("[TapDeck] 未找到加速度计设备")
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return false
        }

        // 注册输入报告回调
        let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDDeviceRegisterInputReportCallback(
            device,
            reportBuffer,
            64,
            { context, result, sender, type, reportID, report, reportLength in
                guard let ctx = context else { return }
                let engine = Unmanaged<TapEngine>.fromOpaque(ctx).takeUnretainedValue()
                engine.handleReport(report: report, length: reportLength)
            },
            context
        )

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        hidManager = manager
        return true
    }

    /// 处理加速度计原始报告
    private nonisolated func handleReport(report: UnsafePointer<UInt8>, length: Int) {
        // Apple SPU 加速度计报告格式：
        // 报告中包含 16-bit little-endian 的 X, Y, Z 值
        // 缩放因子约为 1/16384（转换为 g）
        guard length >= 8 else { return }

        let scale: Double = 1.0 / 16384.0
        let x = Double(Int16(report[2]) | (Int16(report[3]) << 8)) * scale
        let y = Double(Int16(report[4]) | (Int16(report[5]) << 8)) * scale
        let z = Double(Int16(report[6]) | (Int16(report[7]) << 8)) * scale

        let amplitude = sqrt(x * x + y * y + z * z) - 1.0 // 减去重力

        Task { @MainActor in
            if detector.process(amplitude: abs(amplitude), threshold: sensitivity) {
                onTapDetected(amplitude: abs(amplitude))
            }
        }
    }

    // MARK: - 拍击响应

    private func onTapDetected(amplitude: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastTapTime) > cooldown else { return }
        lastTapTime = now
        tapCount += 1

        print("[TapDeck] 拍击 #\(tapCount) amp=\(String(format: "%.4f", amplitude))g")

        // MVP 动作：切换麦克风静音
        toggleMicMute()
    }

    private func toggleMicMute() {
        isMicMuted.toggle()
        MicController.setMuted(isMicMuted)
        print("[TapDeck] 麦克风 \(isMicMuted ? "已静音" : "已开启")")
    }
}

// MARK: - 拍击检测算法

/// 简化版 STA/LTA 拍击检测
struct TapDetector {
    private var shortTermAvg: Double = 0
    private var longTermAvg: Double = 0
    private let shortAlpha: Double = 0.3   // 短时窗口平滑系数
    private let longAlpha: Double = 0.01   // 长时窗口平滑系数
    private let staLtaRatio: Double = 3.0  // STA/LTA 触发比值

    mutating func process(amplitude: Double, threshold: Double) -> Bool {
        shortTermAvg = shortAlpha * amplitude + (1 - shortAlpha) * shortTermAvg
        longTermAvg = longAlpha * amplitude + (1 - longAlpha) * longTermAvg

        // 避免除零
        guard longTermAvg > 0.001 else {
            longTermAvg = max(longTermAvg, 0.001)
            return false
        }

        let ratio = shortTermAvg / longTermAvg
        return ratio > staLtaRatio && amplitude > threshold
    }
}
