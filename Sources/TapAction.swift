import AppKit
import Carbon.HIToolbox
import CoreAudio

/// 可触发的动作类型
enum TapAction: String, CaseIterable, Codable, Identifiable {
    case toggleMic = "切换麦克风静音"
    case playPause = "播放/暂停"
    case screenshot = "截图"
    case lockScreen = "锁屏"
    case doNotDisturb = "勿扰模式"
    case none = "无操作"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .toggleMic: return "mic.slash"
        case .playPause: return "playpause"
        case .screenshot: return "camera.viewfinder"
        case .lockScreen: return "lock"
        case .doNotDisturb: return "moon.fill"
        case .none: return "nosign"
        }
    }

    /// 执行动作
    func execute() {
        switch self {
        case .toggleMic:
            let muted = !MicController.isMuted()
            MicController.setMuted(muted)
            print("[TapAction] 麦克风 \(muted ? "已静音" : "已开启")")
        case .playPause:
            simulateMediaKey(NX_KEYTYPE_PLAY)
            print("[TapAction] 播放/暂停")
        case .screenshot:
            // Cmd+Shift+4（区域截图）
            let src = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x15, keyDown: true) // 4
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x15, keyDown: false)
            keyDown?.flags = [.maskCommand, .maskShift]
            keyUp?.flags = [.maskCommand, .maskShift]
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            print("[TapAction] 截图")
        case .lockScreen:
            // Ctrl+Cmd+Q
            let src = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x0C, keyDown: true) // Q
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x0C, keyDown: false)
            keyDown?.flags = [.maskCommand, .maskControl]
            keyUp?.flags = [.maskCommand, .maskControl]
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            print("[TapAction] 锁屏")
        case .doNotDisturb:
            // 通过 AppleScript 切换勿扰模式
            let script = """
            tell application "System Events" to tell process "ControlCenter"
                click menu bar item "Focus" of menu bar 1
                delay 0.3
                click checkbox 1 of group 1 of window 1
            end tell
            """
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error { print("[TapAction] 勿扰模式切换失败: \(error)") }
                else { print("[TapAction] 勿扰模式已切换") }
            }
        case .none:
            break
        }
    }
}

/// 模拟媒体键（播放/暂停等）
private func simulateMediaKey(_ keyType: Int32) {
    func postEvent(_ keyDown: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: (keyDown ? 0xa00 : 0xb00))
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int((Int32(keyType) << 16) | (keyDown ? 0x0a00 : 0x0b00)),
            data2: -1
        ) else { return }
        let cgEvent = event.cgEvent
        cgEvent?.post(tap: .cghidEventTap)
    }
    postEvent(true)
    postEvent(false)
}
