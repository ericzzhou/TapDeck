import AppKit

/// 娱乐模式音效类型
enum FunSound: String, CaseIterable, Codable, Identifiable {
    case pop = "Pop"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case glass = "Glass"
    case hero = "Hero"
    case morse = "Morse"
    case ping = "Ping"
    case purr = "Purr"
    case submarine = "Submarine"
    case tink = "Tink"

    var id: String { rawValue }

    func play() {
        NSSound(named: NSSound.Name(rawValue))?.play()
    }
}

/// 音效反馈（拍击提示音）
enum SoundFeedback {
    static func play() {
        NSSound(named: "Tink")?.play()
    }
}
