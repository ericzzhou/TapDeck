import SwiftUI

struct MenuBarView: View {
    @ObservedObject var engine: TapEngine

    var body: some View {
        VStack(spacing: 12) {
            // 状态
            HStack {
                Circle()
                    .fill(engine.isListening ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(engine.isListening ? "监听中" : "已停止")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // 麦克风静音状态
            HStack {
                Image(systemName: engine.isMicMuted ? "mic.slash.fill" : "mic.fill")
                    .foregroundColor(engine.isMicMuted ? .red : .green)
                Text(engine.isMicMuted ? "麦克风已静音" : "麦克风开启")
                Spacer()
                Text("拍一下切换")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 拍击计数
            HStack {
                Image(systemName: "hand.tap")
                Text("今日拍击: \(engine.tapCount)")
                Spacer()
            }

            Divider()

            // 灵敏度
            VStack(alignment: .leading, spacing: 4) {
                Text("灵敏度")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $engine.sensitivity, in: 0.01...0.5) {
                    Text("灵敏度")
                }
                HStack {
                    Text("高")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("低")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // 控制按钮
            Button(engine.isListening ? "停止监听" : "开始监听") {
                engine.toggle()
            }
            .keyboardShortcut("t")

            Button("退出 TapDeck") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 260)
    }
}
