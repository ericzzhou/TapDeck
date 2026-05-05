import XCTest

// TapDetector 的镜像副本，用于独立测试 STA/LTA 算法
private struct TapDetector {
    private var shortTermAvg: Double = 0
    private var longTermAvg: Double = 0
    private let shortAlpha: Double = 0.3
    private let longAlpha: Double = 0.01
    private let staLtaRatio: Double = 3.0

    mutating func process(amplitude: Double, threshold: Double) -> Bool {
        shortTermAvg = shortAlpha * amplitude + (1 - shortAlpha) * shortTermAvg
        longTermAvg = longAlpha * amplitude + (1 - longAlpha) * longTermAvg

        guard longTermAvg > 0.001 else {
            longTermAvg = max(longTermAvg, 0.001)
            return false
        }

        let ratio = shortTermAvg / longTermAvg
        return ratio > staLtaRatio && amplitude > threshold
    }
}

final class TapDetectorTests: XCTestCase {

    // MARK: - 基础行为

    func testQuietBaselineProducesNoTap() {
        var detector = TapDetector()
        // 喂入 100 个低幅值样本，不应触发
        for _ in 0..<100 {
            XCTAssertFalse(detector.process(amplitude: 0.001, threshold: 0.05))
        }
    }

    func testSuddenSpikeTriggersDetection() {
        var detector = TapDetector()
        // 先建立低噪声基线
        for _ in 0..<200 {
            _ = detector.process(amplitude: 0.002, threshold: 0.05)
        }
        // 突然出现高幅值 → 应触发
        let triggered = detector.process(amplitude: 0.5, threshold: 0.05)
        XCTAssertTrue(triggered)
    }

    func testBelowThresholdDoesNotTrigger() {
        var detector = TapDetector()
        for _ in 0..<200 {
            _ = detector.process(amplitude: 0.002, threshold: 0.05)
        }
        // 幅值高于基线但低于 threshold
        let triggered = detector.process(amplitude: 0.04, threshold: 0.05)
        XCTAssertFalse(triggered)
    }

    func testColdStartWithHighAmplitudeTriggersOnce() {
        var detector = TapDetector()
        // 冷启动时 longTermAvg 初始为 0，guard 会将其设为 0.001
        // 第一个高幅值样本：shortTermAvg = 0.3*0.3 = 0.09, longTermAvg 被 clamp 到 0.001
        // ratio = 90 > 3.0 且 amplitude 0.3 > threshold 0.05 → 触发
        let triggered = detector.process(amplitude: 0.3, threshold: 0.05)
        XCTAssertTrue(triggered)
    }

    // MARK: - 连续拍击

    func testMultipleSpikesDetectedSeparately() {
        var detector = TapDetector()
        // 建立基线
        for _ in 0..<200 {
            _ = detector.process(amplitude: 0.002, threshold: 0.05)
        }

        // 第一次拍击
        let first = detector.process(amplitude: 0.5, threshold: 0.05)
        XCTAssertTrue(first)

        // 恢复平静
        for _ in 0..<50 {
            _ = detector.process(amplitude: 0.002, threshold: 0.05)
        }

        // 第二次拍击
        let second = detector.process(amplitude: 0.5, threshold: 0.05)
        XCTAssertTrue(second)
    }

    // MARK: - 灵敏度

    func testHighThresholdReducesSensitivity() {
        var detector = TapDetector()
        for _ in 0..<200 {
            _ = detector.process(amplitude: 0.002, threshold: 0.3)
        }
        // 中等幅值，STA/LTA 比值够高但幅值低于高阈值
        let triggered = detector.process(amplitude: 0.2, threshold: 0.3)
        XCTAssertFalse(triggered)
    }

    func testLowThresholdIncreasesSensitivity() {
        var detector = TapDetector()
        for _ in 0..<200 {
            _ = detector.process(amplitude: 0.002, threshold: 0.01)
        }
        // 较小的拍击也能触发
        let triggered = detector.process(amplitude: 0.1, threshold: 0.01)
        XCTAssertTrue(triggered)
    }

    // MARK: - 持续高幅值不应反复触发

    func testSustainedHighAmplitudeStopsTriggeringAfterAdaptation() {
        var detector = TapDetector()
        for _ in 0..<200 {
            _ = detector.process(amplitude: 0.002, threshold: 0.05)
        }

        // 第一个高幅值触发
        XCTAssertTrue(detector.process(amplitude: 0.5, threshold: 0.05))

        // 持续高幅值，长期均值会追上来，比值下降
        var laterTriggers = 0
        for _ in 0..<500 {
            if detector.process(amplitude: 0.5, threshold: 0.05) {
                laterTriggers += 1
            }
        }
        // 适应后不应持续触发（允许前几个还在触发）
        XCTAssertLessThan(laterTriggers, 50, "持续高幅值不应反复触发")
    }
}
