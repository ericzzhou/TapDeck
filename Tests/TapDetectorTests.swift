import XCTest

// TapDetector 镜像（与 TapEngine.swift 中保持同步）
private struct TapDetector {
    private var shortTermAvg: Double = 0
    private var longTermAvg: Double = 0
    private let shortAlpha: Double = 0.4
    private let longAlpha: Double = 0.005
    private let staLtaRatio: Double = 2.5
    private var refractoryCount: Int = 0
    private let refractoryPeriod: Int = 80

    mutating func process(amplitude: Double, threshold: Double) -> Bool {
        shortTermAvg = shortAlpha * amplitude + (1 - shortAlpha) * shortTermAvg
        longTermAvg = longAlpha * amplitude + (1 - longAlpha) * longTermAvg

        guard longTermAvg > 0.001 else {
            longTermAvg = max(longTermAvg, 0.001)
            return false
        }

        if refractoryCount > 0 {
            refractoryCount -= 1
            return false
        }

        let ratio = shortTermAvg / longTermAvg
        let triggered = ratio > staLtaRatio && amplitude > threshold

        if triggered {
            shortTermAvg = longTermAvg
            refractoryCount = refractoryPeriod
        }

        return triggered
    }
}

// 模拟连击检测（与 TapEngine 中 onRawTapDetected 的 cooldown 逻辑一致）
private class TapSimulator {
    var detector = TapDetector()
    var tapCount = 0
    var lastTapSample = -1000  // 上次触发的样本索引
    let cooldownSamples: Int  // rawCooldown 对应的样本数

    // 加速度计约 800Hz，cooldown 0.15s = 120 samples
    init(cooldownMs: Int = 150, sampleRate: Int = 800) {
        cooldownSamples = sampleRate * cooldownMs / 1000
    }

    /// 喂入一系列幅值，返回触发的样本索引列表
    func feed(amplitudes: [Double], threshold: Double) -> [Int] {
        var triggers: [Int] = []
        for (i, amp) in amplitudes.enumerated() {
            if detector.process(amplitude: amp, threshold: threshold) {
                if i - lastTapSample > cooldownSamples {
                    tapCount += 1
                    lastTapSample = i
                    triggers.append(i)
                }
            }
        }
        return triggers
    }
}

/// 生成模拟数据：安静基线 + 拍击脉冲
private func generateSignal(
    baselineNoise: Double = 0.003,
    tapAmplitudes: [Double],
    tapPositions: [Int],  // 样本索引
    tapWidth: Int = 5,    // 拍击脉冲宽度（样本数）
    totalSamples: Int
) -> [Double] {
    var signal = (0..<totalSamples).map { _ in
        Double.random(in: 0...(baselineNoise * 2))
    }
    for (pos, amp) in zip(tapPositions, tapAmplitudes) {
        for j in 0..<tapWidth {
            let idx = pos + j
            guard idx < totalSamples else { break }
            // 拍击脉冲：尖峰后快速衰减
            let decay = exp(-Double(j) * 0.5)
            signal[idx] = amp * decay
        }
    }
    return signal
}

final class TapDetectorTests: XCTestCase {

    // MARK: - 基础行为

    func testQuietBaselineNoTrigger() {
        var detector = TapDetector()
        for _ in 0..<500 {
            XCTAssertFalse(detector.process(amplitude: 0.003, threshold: 0.05))
        }
    }

    func testSingleTapDetected() {
        let sim = TapSimulator()
        // 800 samples 安静 + 1 次拍击
        let signal = generateSignal(
            tapAmplitudes: [0.3],
            tapPositions: [400],
            totalSamples: 800
        )
        let triggers = sim.feed(amplitudes: signal, threshold: 0.05)
        XCTAssertEqual(triggers.count, 1, "应检测到 1 次拍击")
    }

    func testBelowThresholdNoTrigger() {
        let sim = TapSimulator()
        let signal = generateSignal(
            tapAmplitudes: [0.03],  // 低于 threshold
            tapPositions: [400],
            totalSamples: 800
        )
        let triggers = sim.feed(amplitudes: signal, threshold: 0.05)
        XCTAssertEqual(triggers.count, 0, "低于阈值不应触发")
    }

    // MARK: - 连续拍打（核心场景）

    func testRapidTaps_500ms_interval() {
        // 每 500ms 拍一次（400 samples @ 800Hz），共 5 次
        let sim = TapSimulator()
        let positions = [400, 800, 1200, 1600, 2000]
        let signal = generateSignal(
            tapAmplitudes: [0.2, 0.2, 0.2, 0.2, 0.2],
            tapPositions: positions,
            totalSamples: 2400
        )
        let triggers = sim.feed(amplitudes: signal, threshold: 0.05)
        XCTAssertEqual(triggers.count, 5, "500ms 间隔的 5 次拍击应全部检测到，实际 \(triggers.count)")
    }

    func testRapidTaps_300ms_interval() {
        // 每 300ms 拍一次（240 samples），共 5 次
        let sim = TapSimulator()
        let positions = [400, 640, 880, 1120, 1360]
        let signal = generateSignal(
            tapAmplitudes: [0.2, 0.2, 0.2, 0.2, 0.2],
            tapPositions: positions,
            totalSamples: 1800
        )
        let triggers = sim.feed(amplitudes: signal, threshold: 0.05)
        XCTAssertGreaterThanOrEqual(triggers.count, 4, "300ms 间隔应至少检测到 4/5 次，实际 \(triggers.count)")
    }

    func testRapidTaps_200ms_interval() {
        // 每 200ms 拍一次（160 samples），共 8 次 — 快速连拍
        let sim = TapSimulator()
        let positions = (0..<8).map { 400 + $0 * 160 }
        let amps = [Double](repeating: 0.15, count: 8)
        let signal = generateSignal(
            tapAmplitudes: amps,
            tapPositions: positions,
            totalSamples: 2000
        )
        let triggers = sim.feed(amplitudes: signal, threshold: 0.05)
        XCTAssertGreaterThanOrEqual(triggers.count, 6, "200ms 间隔快速连拍应至少检测到 6/8 次，实际 \(triggers.count)")
    }

    // MARK: - 不同力度

    func testLightTap() {
        let sim = TapSimulator()
        let signal = generateSignal(
            tapAmplitudes: [0.08],  // 轻拍
            tapPositions: [400],
            totalSamples: 800
        )
        let triggers = sim.feed(amplitudes: signal, threshold: 0.05)
        XCTAssertEqual(triggers.count, 1, "轻拍（0.08）应能检测到")
    }

    func testVaryingForce() {
        // 力度递减的连续拍打
        let sim = TapSimulator()
        let amps = [0.4, 0.3, 0.2, 0.15, 0.1]
        let positions = [400, 800, 1200, 1600, 2000]
        let signal = generateSignal(
            tapAmplitudes: amps,
            tapPositions: positions,
            totalSamples: 2400
        )
        let triggers = sim.feed(amplitudes: signal, threshold: 0.05)
        XCTAssertGreaterThanOrEqual(triggers.count, 4, "力度递减应至少检测到 4/5 次，实际 \(triggers.count)")
    }

    // MARK: - 持续高幅值不应反复触发

    func testSustainedHighAmplitudeAdapts() {
        var detector = TapDetector()
        // 建立基线
        for _ in 0..<400 {
            _ = detector.process(amplitude: 0.003, threshold: 0.05)
        }
        // 第一个高幅值触发
        XCTAssertTrue(detector.process(amplitude: 0.5, threshold: 0.05))

        // 持续高幅值
        var laterTriggers = 0
        for _ in 0..<500 {
            if detector.process(amplitude: 0.5, threshold: 0.05) {
                laterTriggers += 1
            }
        }
        XCTAssertLessThan(laterTriggers, 20, "持续高幅值不应反复触发")
    }

    // MARK: - 冷启动

    func testColdStartTriggers() {
        var detector = TapDetector()
        let triggered = detector.process(amplitude: 0.3, threshold: 0.05)
        XCTAssertTrue(triggered, "冷启动高幅值应触发")
    }
}
