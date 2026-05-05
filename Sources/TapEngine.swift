import Foundation
import AppKit
import Combine

/// 加速度计数据读取（通过 /usr/bin/python3 helper）+ 拍击检测 + 连击识别 + 动作触发
@MainActor
class TapEngine: ObservableObject {
    @Published var isListening = false
    @Published var isMicMuted = false
    @Published var tapCount = 0
    @Published var isCalibrating = false
    @Published var errorMessage: String?
    @Published var currentAmplitude: Double = 0
    @Published var lastTapTime: Date = .distantPast
    @Published var needsPrivilege = false

    @Published var settings = Settings.shared
    private var settingsSink: AnyCancellable?

    var sensitivity: Double {
        get { settings.sensitivity }
        set { settings.sensitivity = newValue }
    }

    private var detector = TapDetector()
    private var helperProcess: Process?
    private var readTask: Task<Void, Never>?

    // 连击检测
    private var pendingTaps = 0
    private var multiTapTimer: Timer?
    private let multiTapWindow: TimeInterval = 0.4
    private var lastRawTapTime: Date = .distantPast
    private let rawCooldown: TimeInterval = 0.15

    // 自动校准
    private var calibrationSamples: [Double] = []
    private let calibrationCount = 200

    // 娱乐模式播放器
    private(set) var soundPackPlayer: SoundPackPlayer

    init() {
        soundPackPlayer = SoundPackPlayer(pack: Settings.shared.funSoundPack)
        isMicMuted = MicController.isMuted()
        settingsSink = settings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    /// 切换音效包
    func switchSoundPack(_ pack: SoundPack) {
        soundPackPlayer.switchPack(pack)
        settings.funSoundPack = pack
    }

    func toggle() {
        isListening ? stop() : start()
    }

    func start() {
        guard !isListening else { return }

        let helperPath = findHelperBinary()
        guard !helperPath.isEmpty else {
            NSLog("[TapDeck] AccelReader 二进制未找到")
            errorMessage = "AccelReader 未找到，请重新构建项目"
            return
        }

        startHelper(at: helperPath)
    }

    private func startHelper(at path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            NSLog("[TapDeck] 启动失败: %@", error.localizedDescription)
            errorMessage = "启动失败: \(error.localizedDescription)"
            return
        }

        helperProcess = process
        isListening = true
        errorMessage = nil
        isMicMuted = MicController.isMuted()
        NSLog("[TapDeck] AccelReader PID=%d", process.processIdentifier)

        let errHandle = errPipe.fileHandleForReading
        Task.detached { [weak self] in
            while true {
                let data = errHandle.availableData
                guard !data.isEmpty else { break }
                if let text = String(data: data, encoding: .utf8) {
                    let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    NSLog("[TapDeck-helper] %@", msg)
                    if msg.contains("ERROR") {
                        await MainActor.run {
                            self?.errorMessage = "需要管理员权限才能访问加速度计。请点击「以管理员启动」重试。"
                            self?.isListening = false
                            self?.needsPrivilege = true
                        }
                    }
                }
            }
        }

        let fileHandle = pipe.fileHandleForReading
        readTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                let data = fileHandle.availableData
                guard !data.isEmpty else { break }
                guard let text = String(data: data, encoding: .utf8) else { continue }
                for line in text.split(separator: "\n") {
                    if let amplitude = Double(line) {
                        await MainActor.run {
                            self?.handleAmplitude(amplitude)
                        }
                    }
                }
            }
            await MainActor.run {
                self?.isListening = false
                NSLog("[TapDeck] helper 已断开")
            }
        }
    }

    /// 以管理员权限重新启动 helper
    func startWithPrivilege() {
        let helperPath = findHelperBinary()
        guard !helperPath.isEmpty else { return }

        // 通过 osascript 给 helper 设置 setuid bit，之后正常启动即可以 root 运行
        let chownScript = "do shell script \"chmod +s \(helperPath)\" with administrator privileges"
        guard let chown = NSAppleScript(source: chownScript) else {
            errorMessage = "无法创建权限提升脚本"
            return
        }

        var error: NSDictionary?
        chown.executeAndReturnError(&error)
        if let error {
            errorMessage = "权限提升失败: \(error["NSAppleScriptErrorMessage"] ?? "未知错误")"
            return
        }

        needsPrivilege = false
        errorMessage = nil
        startHelper(at: helperPath)
    }

    func stop() {
        readTask?.cancel()
        readTask = nil
        helperProcess?.terminate()
        helperProcess = nil
        multiTapTimer?.invalidate()
        isListening = false
    }

    func startCalibration() {
        calibrationSamples.removeAll()
        isCalibrating = true
    }

    // MARK: - Helper 路径查找

    private func findHelperBinary() -> String {
        let name = "AccelReader"
        // .app bundle MacOS 目录
        if let execPath = Bundle.main.executablePath {
            let macosDir = (execPath as NSString).deletingLastPathComponent
            let p = macosDir + "/" + name
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        // 开发时：与主程序同目录（.build/debug/）
        if let execPath = Bundle.main.executablePath {
            let dir = (execPath as NSString).deletingLastPathComponent
            let p = dir + "/" + name
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        return ""
    }

    // MARK: - 数据处理

    private func handleAmplitude(_ amplitude: Double) {
        currentAmplitude = amplitude
        if isCalibrating {
            handleCalibrationSample(amplitude)
            return
        }
        if detector.process(amplitude: amplitude, threshold: sensitivity) {
            onRawTapDetected(amplitude: amplitude)
        }
    }

    private func handleCalibrationSample(_ amplitude: Double) {
        calibrationSamples.append(amplitude)
        if calibrationSamples.count >= calibrationCount {
            let sorted = calibrationSamples.sorted()
            let p95 = sorted[Int(Double(sorted.count) * 0.95)]
            let newSensitivity = max(0.01, min(0.5, p95 * 3.0))
            sensitivity = newSensitivity
            isCalibrating = false
        }
    }

    // MARK: - 连击检测

    private func onRawTapDetected(amplitude: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastRawTapTime) > rawCooldown else { return }
        lastRawTapTime = now
        lastTapTime = now
        tapCount += 1

        // 娱乐模式：每次拍击立即触发音效
        if settings.funModeEnabled {
            if settings.soundEnabled { SoundFeedback.play() }
            soundPackPlayer.play()
            return
        }

        // 手势模式：连击检测
        pendingTaps += 1
        multiTapTimer?.invalidate()
        multiTapTimer = Timer.scheduledTimer(withTimeInterval: multiTapWindow, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.commitMultiTap()
            }
        }
    }

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

        if settings.soundEnabled {
            SoundFeedback.play()
        }

        // 娱乐模式与手势映射互斥
        if settings.funModeEnabled {
            soundPackPlayer.play()
        } else {
            action.execute()

            if action == .toggleMic {
                isMicMuted = MicController.isMuted()
            }
        }
    }
}

// MARK: - 调试日志

func debugLog(_ message: String) {
    #if DEBUG
    NSLog("[TapDeck] %@", message)
    #endif
}

// MARK: - 拍击检测算法

struct TapDetector {
    private var shortTermAvg: Double = 0
    private var longTermAvg: Double = 0
    private let shortAlpha: Double = 0.4
    private let longAlpha: Double = 0.005
    private let staLtaRatio: Double = 2.5
    private var refractoryCount: Int = 0
    private let refractoryPeriod: Int = 80  // 触发后 80 样本不再触发（~100ms@800Hz）

    mutating func process(amplitude: Double, threshold: Double) -> Bool {
        shortTermAvg = shortAlpha * amplitude + (1 - shortAlpha) * shortTermAvg
        longTermAvg = longAlpha * amplitude + (1 - longAlpha) * longTermAvg

        guard longTermAvg > 0.001 else {
            longTermAvg = max(longTermAvg, 0.001)
            return false
        }

        if refractoryCount > 0 {
            refractoryCount -= 1
            return false
        }

        let ratio = shortTermAvg / longTermAvg
        let triggered = ratio > staLtaRatio && amplitude > threshold

        if triggered {
            shortTermAvg = longTermAvg
            refractoryCount = refractoryPeriod
        }

        return triggered
    }
}
