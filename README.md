# TapDeck

Tap your MacBook, trigger actions. 拍拍你的 Mac，触发快捷操作。

一个 macOS 菜单栏应用，通过 Apple Silicon 加速度计检测物理拍击，触发系统操作。

## 功能

- **连击检测** — 单击、双击、三击触发不同操作
- **6 种动作** — 麦克风静音、播放/暂停、截图、锁屏、勿扰模式、无操作
- **自定义映射** — 每种手势可自由绑定动作，设置自动保存
- **灵敏度调节** — 手动滑块 + 自动校准（采集环境噪声自动设定阈值）
- **音效反馈** — 拍击时播放系统音效
- **开机自启** — 一键配置 launchd 服务

## 默认手势

| 手势 | 默认动作 |
|------|---------|
| 拍一下 | 切换麦克风静音 |
| 拍两下 | 播放/暂停 |
| 拍三下 | 截图 |

## 要求

- macOS 14+ (Sonoma)
- Apple Silicon (M2+)
- 需要 sudo 运行（IOKit HID 加速度计访问权限）

## 构建 & 运行

```bash
swift build
sudo .build/debug/TapDeck
```

## 技术栈

- Swift 5.9 + SwiftUI
- IOKit HID — Apple SPU 加速度计（Bosch BMI286 IMU）
- CoreAudio — 麦克风静音控制
- STA/LTA 算法 — 拍击检测
- UserDefaults — 设置持久化

## 项目结构

```
Sources/
├── TapDeckApp.swift      # 入口 + MenuBarExtra
├── MenuBarView.swift     # 菜单栏 UI
├── TapEngine.swift       # 加速度计 + 拍击检测 + 连击识别
├── TapAction.swift       # 动作定义 + 执行（6 种系统操作）
├── MicController.swift   # 麦克风静音控制（CoreAudio）
├── Settings.swift        # 设置持久化（UserDefaults）
├── LaunchAtLogin.swift   # 开机自启（launchd）
└── SoundFeedback.swift   # 音效反馈
```

## 致谢

灵感来自 [taigrr/spank](https://github.com/taigrr/spank) 和 [olvvier/apple-silicon-accelerometer](https://github.com/olvvier/apple-silicon-accelerometer)。

## License

MIT
