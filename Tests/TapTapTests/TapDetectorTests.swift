import XCTest
@testable import TapTap

final class TapDetectorTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a detector that collects emitted events into an array.
    private func makeDetector(
        config: TapDetectorConfig = TapDetectorConfig()
    ) -> (TapDetector, EventCollector) {
        let detector = TapDetector(config: config)
        let collector = EventCollector()
        detector.onTap = { collector.events.append($0) }
        return (detector, collector)
    }

    /// Simple collector so we can inspect emitted events synchronously.
    private final class EventCollector {
        var events: [TapEvent] = []
    }

    // MARK: - Magnitude / Variance

    func testMagnitudeComputation() {
        // sqrt(3^2 + 4^2 + 0^2) == 5
        let detector = TapDetector()
        // We can verify magnitude indirectly by feeding a sample that should
        // exceed the default threshold (1.5g).
        detector.processSample(x: 3, y: 4, z: 0, timestamp: 0)
        // magnitude = 5 > 1.5 → should trigger
        // Wait for the async timer — but for state we can check immediately
        XCTAssertEqual(detector.state, .waitingForSecondTap)
    }

    func testBelowThresholdDoesNotTrigger() {
        let (detector, collector) = makeDetector()
        // magnitude = sqrt(0.1^2 * 3) ≈ 0.17 < 1.5
        detector.processSample(x: 0.1, y: 0.1, z: 0.1, timestamp: 0)
        XCTAssertEqual(detector.state, .idle)
        XCTAssertTrue(collector.events.isEmpty)
    }

    func testVarianceCalculation() {
        let detector = TapDetector()
        // [2, 2, 2] → variance = 0
        XCTAssertEqual(detector.variance(of: [2, 2, 2]), 0, accuracy: 1e-9)
        // [1, 3] → mean = 2, variance = ((1-2)^2 + (3-2)^2) / 2 = 1
        XCTAssertEqual(detector.variance(of: [1, 3]), 1.0, accuracy: 1e-9)
        // Empty → 0
        XCTAssertEqual(detector.variance(of: []), 0)
    }

    // MARK: - Single Tap (synchronous state check)

    func testSinglePeakTransitionsToWaiting() {
        let (detector, _) = makeDetector()
        detector.processMagnitude(2.0, timestamp: 0)
        XCTAssertEqual(detector.state, .waitingForSecondTap)
    }

    func testSingleTapEmittedAfterTimeout() {
        let config = TapDetectorConfig(doubleTapWindow: 0.1)
        let (detector, collector) = makeDetector(config: config)

        detector.processMagnitude(2.0, timestamp: 0)

        let expectation = XCTestExpectation(description: "single tap emitted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(collector.events, [.singleTap])
        XCTAssertEqual(detector.state, .idle)
    }

    // MARK: - Lockout

    func testLockoutPreventsRinging() {
        let config = TapDetectorConfig(lockoutInterval: 0.120)
        let (detector, _) = makeDetector(config: config)

        // First peak
        detector.processMagnitude(2.0, timestamp: 0)
        XCTAssertEqual(detector.state, .waitingForSecondTap)

        // Ringing peaks within lockout — should be ignored
        detector.processMagnitude(1.8, timestamp: 0.030)
        detector.processMagnitude(1.6, timestamp: 0.060)
        detector.processMagnitude(1.7, timestamp: 0.090)

        // State should still be waiting (not advanced to double tap)
        XCTAssertEqual(detector.state, .waitingForSecondTap)
    }

    func testPeakAfterLockoutIsAccepted() {
        let config = TapDetectorConfig(lockoutInterval: 0.120, doubleTapWindow: 0.350)
        let (detector, collector) = makeDetector(config: config)

        detector.processMagnitude(2.0, timestamp: 0)
        // Second tap after lockout but within double-tap window
        detector.processMagnitude(2.0, timestamp: 0.200)

        XCTAssertEqual(collector.events, [.doubleTap])
        XCTAssertEqual(detector.state, .idle)
    }

    // MARK: - Double Tap

    func testDoubleTapDetection() {
        let config = TapDetectorConfig(
            lockoutInterval: 0.100,
            doubleTapWindow: 0.350
        )
        let (detector, collector) = makeDetector(config: config)

        detector.processMagnitude(2.0, timestamp: 0)
        detector.processMagnitude(2.0, timestamp: 0.250) // within window

        XCTAssertEqual(collector.events, [.doubleTap])
        XCTAssertEqual(detector.state, .idle)
    }

    func testTapOutsideDoubleWindowIsNewFirstTap() {
        let config = TapDetectorConfig(
            lockoutInterval: 0.100,
            doubleTapWindow: 0.350
        )
        let (detector, collector) = makeDetector(config: config)

        detector.processMagnitude(2.0, timestamp: 0)
        // Second tap outside the double-tap window
        detector.processMagnitude(2.0, timestamp: 0.500)

        // Should NOT be a double tap; should start a new waiting state
        XCTAssertTrue(collector.events.isEmpty || collector.events == [.singleTap])
        XCTAssertEqual(detector.state, .waitingForSecondTap)
    }

    // MARK: - Long Tap

    func testLongTapDetectedOnSustainedLowVariance() {
        let config = TapDetectorConfig(
            threshold: 1.5,
            lockoutInterval: 0.050,
            doubleTapWindow: 0.800,
            longTapHoldDuration: 0.300,
            longTapVarianceThreshold: 0.05
        )
        let (detector, collector) = makeDetector(config: config)

        // Initial peak
        detector.processMagnitude(2.0, timestamp: 0)
        XCTAssertEqual(detector.state, .waitingForSecondTap)

        // Sustained low-magnitude, low-variance samples over hold duration
        let sampleCount = 30
        for i in 1...sampleCount {
            let t = Double(i) * 0.011 // ~90 Hz, total ≈ 0.33s
            detector.processMagnitude(0.05, timestamp: t)
        }

        XCTAssertEqual(collector.events, [.longTap])
        XCTAssertEqual(detector.state, .idle)
    }

    func testHighVarianceDuringHoldDoesNotTriggerLongTap() {
        let config = TapDetectorConfig(
            threshold: 1.5,
            lockoutInterval: 0.050,
            doubleTapWindow: 0.800,
            longTapHoldDuration: 0.300,
            longTapVarianceThreshold: 0.001
        )
        let (detector, collector) = makeDetector(config: config)

        detector.processMagnitude(2.0, timestamp: 0)

        // Noisy hold samples — high variance
        for i in 1...30 {
            let t = Double(i) * 0.011
            let noisy = Double(i % 2 == 0 ? 0.5 : 0.0)
            detector.processMagnitude(noisy, timestamp: t)
        }

        // Long tap should NOT have been emitted
        XCTAssertFalse(collector.events.contains(.longTap))
    }

    func testSecondSpikeAbortLongTapTracking() {
        let config = TapDetectorConfig(
            threshold: 1.5,
            lockoutInterval: 0.050,
            doubleTapWindow: 0.350,
            longTapHoldDuration: 0.300,
            longTapVarianceThreshold: 0.05
        )
        let (detector, collector) = makeDetector(config: config)

        detector.processMagnitude(2.0, timestamp: 0)

        // A few calm samples
        detector.processMagnitude(0.05, timestamp: 0.020)
        detector.processMagnitude(0.05, timestamp: 0.040)

        // Second spike within double-tap window (and after lockout)
        detector.processMagnitude(2.0, timestamp: 0.200)

        XCTAssertEqual(collector.events, [.doubleTap])
        XCTAssertEqual(detector.state, .idle)
    }

    // MARK: - Reset

    func testResetClearsState() {
        let (detector, collector) = makeDetector()

        detector.processMagnitude(2.0, timestamp: 0)
        XCTAssertEqual(detector.state, .waitingForSecondTap)

        detector.reset()

        XCTAssertEqual(detector.state, .idle)
        // After reset a new peak should start fresh
        detector.processMagnitude(2.0, timestamp: 1.0)
        XCTAssertEqual(detector.state, .waitingForSecondTap)
        XCTAssertTrue(collector.events.isEmpty) // no doubleTap across reset
    }

    // MARK: - TapEvent

    func testTapEventEquality() {
        XCTAssertEqual(TapEvent.singleTap, TapEvent.singleTap)
        XCTAssertEqual(TapEvent.doubleTap, TapEvent.doubleTap)
        XCTAssertEqual(TapEvent.longTap, TapEvent.longTap)
        XCTAssertNotEqual(TapEvent.singleTap, TapEvent.doubleTap)
    }
}
