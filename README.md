# TapDeck

Tap your MacBook, trigger actions. 拍拍你的 Mac，触发快捷操作。

一个 macOS 菜单栏应用，通过 Apple Silicon 加速度计检测物理拍击，触发系统操作。

## MVP 功能

**拍一下 → 切换麦克风静音**

开视频会议时，拍一下 MacBook 比找静音按钮快 10 倍。

## 要求

- macOS 14+ (Sonoma)
- Apple Silicon (M2+)
- 需要 sudo 运行（IOKit HID 加速度计访问权限）

## 构建 & 运行

```bash
# 构建
swift build

# 运行（需要 sudo）
sudo .build/debug/TapDeck
```

## 技术栈

- Swift 5.9 + SwiftUI
- IOKit HID — 读取 Apple SPU 加速度计（Bosch BMI286 IMU）
- CoreAudio — 系统麦克风静音控制
- STA/LTA 算法 — 拍击检测

## 项目结构

```
Sources/
├── TapDeckApp.swift      # 入口 + MenuBarExtra
├── MenuBarView.swift     # 菜单栏 UI
├── TapEngine.swift       # 加速度计读取 + 拍击检测
└── MicController.swift   # 麦克风静音控制（CoreAudio）
```

## 路线图

- [x] MVP: 拍击 → 麦克风静音切换
- [ ] 连击检测（拍两下、拍三下触发不同操作）
- [ ] 自定义动作映射（静音、播放/暂停、截图、锁屏等）
- [ ] 灵敏度自动校准
- [ ] 开机自启（launchd）
- [ ] 音效反馈
- [ ] Mac App Store 上架

## 致谢

灵感来自 [taigrr/spank](https://github.com/taigrr/spank) 和 [olvvier/apple-silicon-accelerometer](https://github.com/olvvier/apple-silicon-accelerometer)。

## License

MIT
