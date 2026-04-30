import Foundation
import IOKit
import IOKit.hid

/// 加速度计数据读取 + 拍击检测 + 连击识别 + 动作触发
@MainActor
class TapEngine: ObservableObject {
    @Published var isListening = false
    @Published var isMicMuted = false
    @Published var tapCount = 0
    @Published var sensitivity: Double {
        didSet { Settings.shared.sensitivity = sensitivity }
    }
    @Published var isCalibrating = false

    @Published var settings = Settings.shared

    private var hidManager: IOHIDManager?
    private var detector = TapDetector()

    // 连击检测
    private var pendingTaps = 0
    private var multiTapTimer: Timer?
    private let multiTapWindow: TimeInterval = 0.4 // 连击判定窗口
    private var lastRawTapTime: Date = .distantPast
    private let rawCooldown: TimeInterval = 0.15 // 单次拍击最小间隔（去抖）

    // 自动校准
    private var calibrationSamples: [Double] = []
    private let calibrationCount = 200

    init() {
        self.sensitivity = Settings.shared.sensitivity
    }

    func toggle() {
        isListening ? stop() : start()
    }

    func start() {
        guard !isListening else { return }
        guard openAccelerometer() else {
            print("[TapDeck] 无法打开加速度计，请确认以 sudo 运行或授予权限")
            return
        }
        isListening = true
        isMicMuted = MicController.isMuted()
        print("[TapDeck] 开始监听拍击")
    }

    func stop() {
        if let mgr = hidManager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            hidManager = nil
        }
        multiTapTimer?.invalidate()
        isListening = false
        print("[TapDeck] 停止监听")
    }

    /// 启动自动校准：采集环境噪声，自动设置灵敏度阈值
    func startCalibration() {
        calibrationSamples.removeAll()
        isCalibrating = true
        print("[TapDeck] 开始校准，请保持静止...")
    }

    // MARK: - IOKit HID 加速度计

    private func openAccelerometer() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: 0x20,
            kIOHIDDeviceUsageKey as String: 0x73,
        ]
        IOHIDManagerSetDeviceMatching(manager, matchDict as CFDictionary)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            print("[TapDeck] IOHIDManagerOpen 失败: \(result)")
            return false
        }

        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = deviceSet.first else {
            print("[TapDeck] 未找到加速度计设备")
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return false
        }

        let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDDeviceRegisterInputReportCallback(
            device, reportBuffer, 64,
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

    private nonisolated func handleReport(report: UnsafePointer<UInt8>, length: Int) {
        guard length >= 8 else { return }

        let scale: Double = 1.0 / 16384.0
        let x = Double(Int16(report[2]) | (Int16(report[3]) << 8)) * scale
        let y = Double(Int16(report[4]) | (Int16(report[5]) << 8)) * scale
        let z = Double(Int16(report[6]) | (Int16(report[7]) << 8)) * scale

        let amplitude = abs(sqrt(x * x + y * y + z * z) - 1.0)

        Task { @MainActor in
            // 校准模式：收集环境噪声样本
            if isCalibrating {
                handleCalibrationSample(amplitude)
                return
            }

            if detector.process(amplitude: amplitude, threshold: sensitivity) {
                onRawTapDetected(amplitude: amplitude)
            }
        }
    }

    // MARK: - 自动校准

    private func handleCalibrationSample(_ amplitude: Double) {
        calibrationSamples.append(amplitude)
        if calibrationSamples.count >= calibrationCount {
            let sorted = calibrationSamples.sorted()
            // 取 95 百分位作为噪声上限，阈值设为噪声的 3 倍
            let p95 = sorted[Int(Double(sorted.count) * 0.95)]
            let newSensitivity = max(0.01, min(0.5, p95 * 3.0))
            sensitivity = newSensitivity
            isCalibrating = false
            print("[TapDeck] 校准完成，噪声 p95=\(String(format: "%.4f", p95))g，灵敏度设为 \(String(format: "%.4f", newSensitivity))")
        }
    }

    // MARK: - 连击检测

    private func onRawTapDetected(amplitude: Double) {
        let now = Date()
        // 去抖：太快的连续触发忽略
        guard now.timeIntervalSince(lastRawTapTime) > rawCooldown else { return }
        lastRawTapTime = now
        tapCount += 1

        pendingTaps += 1
        // 重置连击计时器
        multiTapTimer?.invalidate()
        multiTapTimer = Timer.scheduledTimer(withTimeInterval: multiTapWindow, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.commitMultiTap()
            }
        }
    }

    /// 连击窗口结束，根据拍击次数执行对应动作
    private func commitMultiTap() {
        let taps = pendingTaps
        pendingTaps = 0

        let action: TapAction
        switch taps {
        case 1: action = settings.singleTapAction
        case 2: action = settings.doubleTapAction
        case 3...: action = settings.tripleTapAction
        default: return
        }

        print("[TapDeck] \(taps)连击 → \(action.rawValue)")

        // 音效反馈
        if settings.soundEnabled {
            SoundFeedback.play()
        }

        // 执行动作
        action.execute()

        // 更新麦克风状态（如果动作是切换麦克风）
        if action == .toggleMic {
            isMicMuted = MicController.isMuted()
        }
    }
}

// MARK: - 拍击检测算法

/// 简化版 STA/LTA 拍击检测
struct TapDetector {
    private var shortTermAvg: Double = 0
    private var longTermAvg: Double = 0
    private let shortAlpha: Double = 0.3
    private let longAlpha: Double = 0.01
    private let staLtaRatio: Double = 3.0

    mutating func process(amplitude: Double, threshold: Double) -> Bool {
        shortTermAvg = shortAlpha * amplitude + (1 - shortAlpha) * shortTermAvg
        longTermAvg = longAlpha * amplitude + (1 - longAlpha) * longTermAvg

        guard longTermAvg > 0.001 else {
            longTermAvg = max(longTermAvg, 0.001)
            return false
        }

        let ratio = shortTermAvg / longTermAvg
        return ratio > staLtaRatio && amplitude > threshold
    }
}
