import SwiftUI

struct MenuBarView: View {
    @ObservedObject var engine: TapEngine
    @State private var selectedTab: Int

    init(engine: TapEngine) {
        self._engine = ObservedObject(wrappedValue: engine)
        self._selectedTab = State(initialValue: engine.settings.funModeEnabled ? 0 : 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            // 状态栏
            statusSection

            Divider()

            // 选项卡：娱乐模式 / 手势映射
            Picker("", selection: $selectedTab) {
                Text("🎵 娱乐").tag(0)
                Text("⚡ 手势").tag(1)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTab) { _, newValue in
                engine.settings.funModeEnabled = (newValue == 0)
            }

            if selectedTab == 0 {
                funModeSection
            } else {
                actionMappingSection
            }

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

            // 实时振幅指示器
            if engine.isListening {
                AmplitudeBar(amplitude: engine.currentAmplitude, threshold: engine.sensitivity, lastTapTime: engine.lastTapTime)
            }

            // 错误提示
            if let error = engine.errorMessage {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .lineLimit(2)
                    }
                    if engine.needsPrivilege {
                        Button("以管理员权限启动") {
                            engine.startWithPrivilege()
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
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
                Slider(value: Binding(
                    get: { engine.sensitivity },
                    set: { engine.sensitivity = $0 }
                ), in: 0.01...0.5)
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

    // MARK: - 娱乐模式

    private var funModeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("拍击时播放音效")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Picker("音效", selection: $engine.settings.funSound) {
                    ForEach(FunSound.allCases) { sound in
                        Text(sound.rawValue).tag(sound)
                    }
                }
                .labelsHidden()

                Button("试听") {
                    engine.settings.funSound.play()
                }
                .font(.caption2)
                .buttonStyle(.borderless)
            }
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

// MARK: - 振幅指示器

struct AmplitudeBar: View {
    let amplitude: Double
    let threshold: Double
    let lastTapTime: Date

    private var level: Double {
        min(1.0, amplitude / max(threshold * 2, 0.01))
    }

    private var detected: Bool {
        Date().timeIntervalSince(lastTapTime) < 0.5
    }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                    // 振幅条
                    RoundedRectangle(cornerRadius: 3)
                        .fill(detected ? Color.orange : Color.green)
                        .frame(width: geo.size.width * level)
                        .animation(.easeOut(duration: 0.05), value: level)
                    // 阈值线
                    Rectangle()
                        .fill(Color.red.opacity(0.6))
                        .frame(width: 1)
                        .offset(x: geo.size.width * min(1.0, threshold / max(threshold * 2, 0.01)))
                }
            }
            .frame(height: 6)

            HStack {
                Text(detected ? "✓ 检测到拍击" : "等待拍击...")
                    .font(.caption2)
                    .foregroundColor(detected ? .orange : .secondary)
                Spacer()
            }
        }
    }
}
