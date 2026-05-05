import AppKit
import AVFoundation

// MARK: - 音效包类型

enum SoundPack: String, CaseIterable, Codable, Identifiable {
    case pain = "痛叫"
    case sexy = "性感"
    case halo = "光环"

    var id: String { rawValue }

    /// 音效包目录名
    var dirName: String {
        switch self {
        case .pain: return "pain"
        case .sexy: return "sexy"
        case .halo: return "halo"
        }
    }

    /// 播放模式：random 或 escalation
    var isEscalation: Bool {
        switch self {
        case .sexy: return true
        case .pain, .halo: return false
        }
    }
}

// MARK: - 拍打频率追踪器（移植自 spank 的 slapTracker）

class SlapTracker {
    private var score: Double = 0
    private var lastTime: Date = .distantPast
    private(set) var total: Int = 0
    private let halfLife: Double = 30.0  // 30秒衰减一半

    /// 记录一次拍击，返回当前 score
    func record() -> Double {
        let now = Date()
        if lastTime != .distantPast {
            let elapsed = now.timeIntervalSince(lastTime)
            score *= pow(0.5, elapsed / halfLife)
        }
        score += 1.0
        lastTime = now
        total += 1
        return score
    }

    func reset() {
        score = 0
        lastTime = .distantPast
        total = 0
    }
}

// MARK: - 音效包播放器

class SoundPackPlayer {
    private var files: [URL] = []
    private var player: AVAudioPlayer?
    private let tracker = SlapTracker()
    private(set) var pack: SoundPack

    init(pack: SoundPack) {
        self.pack = pack
        loadFiles()
    }

    func switchPack(_ newPack: SoundPack) {
        pack = newPack
        loadFiles()
        tracker.reset()
    }

    private func loadFiles() {
        files = findAudioFiles(for: pack)
        files.sort { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 播放一次（根据频率选择文件）
    func play() {
        guard !files.isEmpty else { return }

        let score = tracker.record()
        let file: URL

        if pack.isEscalation {
            // 升级模式：score 越高，索引越大，音效越激烈
            let maxIdx = files.count - 1
            let scale = Double(files.count) / log(Double(files.count + 1))
            let idx = min(Int(Double(files.count) * (1.0 - exp(-(score - 1) / scale))), maxIdx)
            file = files[idx]
        } else {
            // 随机模式
            file = files[Int.random(in: 0..<files.count)]
        }

        do {
            player = try AVAudioPlayer(contentsOf: file)
            player?.play()
        } catch {
            NSLog("[SoundPackPlayer] 播放失败: %@", error.localizedDescription)
        }
    }

    /// 查找音效文件
    private func findAudioFiles(for pack: SoundPack) -> [URL] {
        let dirName = pack.dirName

        // .app bundle Resources/Audio/
        if let resourcePath = Bundle.main.resourcePath {
            let dir = URL(fileURLWithPath: resourcePath).appendingPathComponent("Audio/\(dirName)")
            if let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                let mp3s = urls.filter { $0.pathExtension == "mp3" }
                if !mp3s.isEmpty { return mp3s }
            }
        }

        // 开发时：项目根/Resources/Audio/
        if let execPath = Bundle.main.executablePath {
            let dir = (execPath as NSString).deletingLastPathComponent
            // .build/debug/ -> 项目根
            for root in [dir, (dir as NSString).deletingLastPathComponent, ((dir as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent] {
                let audioDir = URL(fileURLWithPath: root).appendingPathComponent("Resources/Audio/\(dirName)")
                if let urls = try? FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil) {
                    let mp3s = urls.filter { $0.pathExtension == "mp3" }
                    if !mp3s.isEmpty { return mp3s }
                }
            }
        }

        return []
    }
}

// MARK: - 音效反馈（拍击提示音）

enum SoundFeedback {
    static func play() {
        NSSound(named: "Tink")?.play()
    }
}
