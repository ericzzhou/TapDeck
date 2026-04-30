import Foundation
import ServiceManagement

/// 开机自启管理（launchd）
enum LaunchAtLogin {
    private static let plistLabel = "com.ericzzhou.TapDeck"
    private static var plistPath: String {
        NSHomeDirectory() + "/Library/LaunchAgents/\(plistLabel).plist"
    }

    static func setEnabled(_ enabled: Bool) {
        if enabled {
            install()
        } else {
            uninstall()
        }
    }

    static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    private static func install() {
        guard let execPath = Bundle.main.executablePath ?? CommandLine.arguments.first else {
            print("[LaunchAtLogin] 无法获取可执行文件路径")
            return
        }

        let plist: [String: Any] = [
            "Label": plistLabel,
            "ProgramArguments": [execPath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "StandardOutPath": "/tmp/tapdeck.log",
            "StandardErrorPath": "/tmp/tapdeck.err",
        ]

        let url = URL(fileURLWithPath: plistPath)
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: url)
            // 加载服务
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["load", plistPath]
            try task.run()
            task.waitUntilExit()
            print("[LaunchAtLogin] 已启用开机自启")
        } catch {
            print("[LaunchAtLogin] 安装失败: \(error)")
        }
    }

    private static func uninstall() {
        // 卸载服务
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["unload", plistPath]
        try? task.run()
        task.waitUntilExit()

        try? FileManager.default.removeItem(atPath: plistPath)
        print("[LaunchAtLogin] 已禁用开机自启")
    }
}
