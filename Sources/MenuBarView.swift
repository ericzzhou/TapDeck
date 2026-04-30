import SwiftUI

struct MenuBarView: View {
    @ObservedObject var engine: TapEngine

    var body: some View {
        VStack(spacing: 10) {
            // 状态栏
            statusSection

            Divider()

            // 动作映射
            actionMappingSection

            Divider()

            // 设置
            settingsSection

            Divider()

            // 控制
            controlSection
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - 状态

    private var statusSection: some View {
        VStack(spacing: 6) {
            HStack {
                Circle()
                    .fill(engine.isListening ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(engine.isListening ? "监听中" : "已停止")
                    .font(.headline)
                Spacer()
                Text("拍击 \(engine.tapCount) 次")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 麦克风状态
            HStack {
                Image(systemName: engine.isMicMuted ? "mic.slash.fill" : "mic.fill")
                    .foregroundColor(engine.isMicMuted ? .red : .green)
                Text(engine.isMicMuted ? "麦克风已静音" : "麦克风开启")
                    .font(.subheadline)
                Spacer()
            }
        }
    }

    // MARK: - 动作映射

    private var actionMappingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("手势映射")
                .font(.caption)
                .foregroundColor(.secondary)

            ActionRow(label: "拍一下", icon: "1.circle", action: $engine.settings.singleTapAction)
            ActionRow(label: "拍两下", icon: "2.circle", action: $engine.settings.doubleTapAction)
            ActionRow(label: "拍三下", icon: "3.circle", action: $engine.settings.tripleTapAction)
        }
    }

    // MARK: - 设置

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 灵敏度
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("灵敏度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if engine.isCalibrating {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("校准中...")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Button("自动校准") {
                            engine.startCalibration()
                        }
                        .font(.caption2)
                        .buttonStyle(.borderless)
                    }
                }
                Slider(value: $engine.sensitivity, in: 0.01...0.5)
                HStack {
                    Text("高").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("低").font(.caption2).foregroundColor(.secondary)
                }
            }

            // 音效 + 开机自启
            HStack {
                Toggle("音效反馈", isOn: $engine.settings.soundEnabled)
                    .font(.caption)
                Spacer()
                Toggle("开机自启", isOn: $engine.settings.launchAtLogin)
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
        }
    }

    // MARK: - 控制按钮

    private var controlSection: some View {
        HStack {
            Button(engine.isListening ? "停止" : "开始") {
                engine.toggle()
            }
            .keyboardShortcut("t")

            Spacer()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

// MARK: - 动作选择行

struct ActionRow: View {
    let label: String
    let icon: String
    @Binding var action: TapAction

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 16)
            Text(label)
                .font(.subheadline)
            Spacer()
            Picker("", selection: $action) {
                ForEach(TapAction.allCases) { a in
                    Label(a.rawValue, systemImage: a.icon).tag(a)
                }
            }
            .labelsHidden()
            .frame(width: 140)
        }
    }
}
