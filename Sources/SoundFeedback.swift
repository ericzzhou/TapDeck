import AppKit

/// 音效反馈
enum SoundFeedback {
    /// 播放系统音效
    static func play() {
        NSSound(named: "Tink")?.play()
    }
}
