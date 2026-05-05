import Foundation

/// 持久化设置（UserDefaults）
class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    /// 拍击手势 → 动作映射
    @Published var singleTapAction: TapAction {
        didSet { defaults.set(singleTapAction.rawValue, forKey: "singleTapAction") }
    }
    @Published var doubleTapAction: TapAction {
        didSet { defaults.set(doubleTapAction.rawValue, forKey: "doubleTapAction") }
    }
    @Published var tripleTapAction: TapAction {
        didSet { defaults.set(tripleTapAction.rawValue, forKey: "tripleTapAction") }
    }

    /// 灵敏度
    @Published var sensitivity: Double {
        didSet { defaults.set(sensitivity, forKey: "sensitivity") }
    }

    /// 音效反馈
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: "soundEnabled") }
    }

    /// 娱乐模式
    @Published var funModeEnabled: Bool {
        didSet { defaults.set(funModeEnabled, forKey: "funModeEnabled") }
    }

    /// 娱乐模式音效
    @Published var funSoundPack: SoundPack {
        didSet { defaults.set(funSoundPack.rawValue, forKey: "funSoundPack") }
    }

    /// 开机自启
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: "launchAtLogin")
            LaunchAtLogin.setEnabled(launchAtLogin)
        }
    }

    private init() {
        self.singleTapAction = TapAction(rawValue: defaults.string(forKey: "singleTapAction") ?? "") ?? .toggleMic
        self.doubleTapAction = TapAction(rawValue: defaults.string(forKey: "doubleTapAction") ?? "") ?? .playPause
        self.tripleTapAction = TapAction(rawValue: defaults.string(forKey: "tripleTapAction") ?? "") ?? .screenshot
        self.sensitivity = defaults.object(forKey: "sensitivity") as? Double ?? 0.02
        self.soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        self.funModeEnabled = defaults.object(forKey: "funModeEnabled") as? Bool ?? true
        self.funSoundPack = SoundPack(rawValue: defaults.string(forKey: "funSoundPack") ?? "") ?? .pain
        self.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
    }
}
