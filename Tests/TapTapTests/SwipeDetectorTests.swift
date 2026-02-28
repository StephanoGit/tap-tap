import XCTest
@testable import TapTap

final class SwipeDetectorTests: XCTestCase {

    // MARK: - Helpers

    private func makeDetector(
        config: SwipeDetectorConfig = SwipeDetectorConfig()
    ) -> (SwipeDetector, SwipeEventCollector) {
        let detector = SwipeDetector(config: config)
        let collector = SwipeEventCollector()
        detector.onSwipe = { collector.events.append($0) }
        return (detector, collector)
    }

    private final class SwipeEventCollector {
        var events: [SwipeEvent] = []
    }

    /// Simulates a swipe by generating an acceleration → deceleration
    /// pattern along the given axis over the given duration.
    ///
    /// - Parameters:
    ///   - detector: The detector to feed samples to.
    ///   - axis: Which axis to apply the acceleration on ("x", "y").
    ///   - positive: If `true`, acceleration is in the positive direction.
    ///   - peakAccel: Maximum acceleration in g.
    ///   - duration: Total swipe duration in seconds.
    ///   - startTime: Timestamp for the first sample.
    ///   - sampleRate: Samples per second.
    private func simulateSwipe(
        detector: SwipeDetector,
        axis: String,
        positive: Bool,
        peakAccel: Double = 1.0,
        duration: Double = 0.200,
        startTime: Double = 0,
        sampleRate: Double = 100
    ) {
        let dt = 1.0 / sampleRate
        let steps = Int(duration * sampleRate)
        let halfSteps = steps / 2
        let sign: Double = positive ? 1.0 : -1.0

        for i in 0..<steps {
            let t = startTime + Double(i) * dt
            // Ramp up in first half, ramp down in second half
            let progress: Double
            if i < halfSteps {
                progress = Double(i) / Double(halfSteps) // 0→1
            } else {
                progress = Double(steps - i) / Double(steps - halfSteps) // 1→0
            }
            let accel = sign * peakAccel * progress

            let x: Double
            let y: Double
            let z: Double
            switch axis {
            case "x":  x = accel; y = 0.02; z = 0.02  // small noise on other axes
            case "y":  x = 0.02; y = accel; z = 0.02
            default:   x = 0.02; y = 0.02; z = accel
            }
            detector.processSample(x: x, y: y, z: z, timestamp: t)
        }
    }

    // MARK: - SwipeEvent Equality

    func testSwipeEventEquality() {
        XCTAssertEqual(SwipeEvent.swipeLeft, SwipeEvent.swipe(.left))
        XCTAssertEqual(SwipeEvent.swipeRight, SwipeEvent.swipe(.right))
        XCTAssertEqual(SwipeEvent.swipeUp, SwipeEvent.swipe(.up))
        XCTAssertEqual(SwipeEvent.swipeDown, SwipeEvent.swipe(.down))
        XCTAssertNotEqual(SwipeEvent.swipeLeft, SwipeEvent.swipeRight)
        XCTAssertNotEqual(SwipeEvent.swipeUp, SwipeEvent.swipeDown)
    }

    // MARK: - Basic Direction Detection

    func testSwipeRightDetected() {
        let (detector, collector) = makeDetector()
        simulateSwipe(detector: detector, axis: "x", positive: true)
        XCTAssertEqual(collector.events, [.swipeRight])
        XCTAssertEqual(detector.state, .idle)
    }

    func testSwipeLeftDetected() {
        let (detector, collector) = makeDetector()
        simulateSwipe(detector: detector, axis: "x", positive: false)
        XCTAssertEqual(collector.events, [.swipeLeft])
        XCTAssertEqual(detector.state, .idle)
    }

    func testSwipeUpDetected() {
        let (detector, collector) = makeDetector()
        simulateSwipe(detector: detector, axis: "y", positive: true)
        XCTAssertEqual(collector.events, [.swipeUp])
        XCTAssertEqual(detector.state, .idle)
    }

    func testSwipeDownDetected() {
        let (detector, collector) = makeDetector()
        simulateSwipe(detector: detector, axis: "y", positive: false)
        XCTAssertEqual(collector.events, [.swipeDown])
        XCTAssertEqual(detector.state, .idle)
    }

    // MARK: - Below Threshold

    func testBelowThresholdDoesNotActivate() {
        let (detector, collector) = makeDetector()
        // All samples below activation threshold
        for i in 0..<20 {
            let t = Double(i) * 0.01
            detector.processSample(x: 0.1, y: 0.1, z: 0.1, timestamp: t)
        }
        XCTAssertEqual(detector.state, .idle)
        XCTAssertTrue(collector.events.isEmpty)
    }

    // MARK: - Diagonal Rejection

    func testDiagonalMotionRejected() {
        let config = SwipeDetectorConfig(axisRatio: 1.5)
        let (detector, collector) = makeDetector(config: config)

        // Equal acceleration on X and Y — not clearly directional
        let steps = 20
        for i in 0..<steps {
            let t = Double(i) * 0.01
            let progress = Double(i < steps / 2 ? i : steps - i) / Double(steps / 2)
            let accel = 1.0 * progress
            detector.processSample(x: accel, y: accel, z: 0.01, timestamp: t)
        }

        XCTAssertTrue(collector.events.isEmpty)
    }

    // MARK: - Z-axis Rejection

    func testZAxisSwipeIgnored() {
        let (detector, collector) = makeDetector()
        simulateSwipe(detector: detector, axis: "z", positive: true)
        XCTAssertTrue(collector.events.isEmpty)
    }

    // MARK: - Cooldown

    func testCooldownPreventsRapidSwipes() {
        let config = SwipeDetectorConfig(cooldown: 0.300)
        let (detector, collector) = makeDetector(config: config)

        // First swipe
        simulateSwipe(detector: detector, axis: "x", positive: true, startTime: 0)

        // Second swipe within cooldown — should be ignored
        simulateSwipe(detector: detector, axis: "x", positive: true, startTime: 0.250)

        XCTAssertEqual(collector.events.count, 1)
        XCTAssertEqual(collector.events.first, .swipeRight)
    }

    func testSwipeAfterCooldownAccepted() {
        let config = SwipeDetectorConfig(cooldown: 0.300)
        let (detector, collector) = makeDetector(config: config)

        // First swipe
        simulateSwipe(detector: detector, axis: "x", positive: true, startTime: 0)

        // Second swipe after cooldown
        simulateSwipe(detector: detector, axis: "y", positive: false, startTime: 0.600)

        XCTAssertEqual(collector.events.count, 2)
        XCTAssertEqual(collector.events[0], .swipeRight)
        XCTAssertEqual(collector.events[1], .swipeDown)
    }

    // MARK: - Timeout

    func testSwipeTimesOutWithInsufficientDisplacement() {
        let config = SwipeDetectorConfig(
            activationThreshold: 0.4,
            maxSwipeDuration: 0.200,
            minDisplacement: 5.0 // Very high — won't be reached
        )
        let (detector, collector) = makeDetector(config: config)

        // Brief motion that triggers tracking but times out with
        // displacement well below the high minDisplacement threshold.
        simulateSwipe(detector: detector, axis: "x", positive: true,
                      peakAccel: 0.8, duration: 0.250)

        // No swipe should be emitted because displacement is insufficient
        XCTAssertTrue(collector.events.isEmpty)
    }

    // MARK: - Reset

    func testResetClearsState() {
        let (detector, collector) = makeDetector()

        // Start tracking
        detector.processSample(x: 1.0, y: 0.01, z: 0.01, timestamp: 0)
        XCTAssertEqual(detector.state, .tracking)

        detector.reset()
        XCTAssertEqual(detector.state, .idle)

        // After reset, a new swipe should start fresh
        simulateSwipe(detector: detector, axis: "x", positive: true, startTime: 1.0)
        XCTAssertEqual(collector.events, [.swipeRight])
    }

    // MARK: - Minimum Displacement

    func testTinyMotionDoesNotTriggerSwipe() {
        let config = SwipeDetectorConfig(
            activationThreshold: 0.4,
            minDisplacement: 0.5 // High bar
        )
        let (detector, collector) = makeDetector(config: config)

        // Brief, small activation — not enough displacement
        detector.processSample(x: 0.5, y: 0.01, z: 0.01, timestamp: 0)
        detector.processSample(x: 0.0, y: 0.01, z: 0.01, timestamp: 0.01)
        detector.processSample(x: -0.1, y: 0.01, z: 0.01, timestamp: 0.02)

        XCTAssertTrue(collector.events.isEmpty)
    }

    // MARK: - State Transitions

    func testActivationTransitionsToTracking() {
        let (detector, _) = makeDetector()
        detector.processSample(x: 1.0, y: 0.01, z: 0.01, timestamp: 0)
        XCTAssertEqual(detector.state, .tracking)
    }

    func testCompletedSwipeReturnsToIdle() {
        let (detector, collector) = makeDetector()
        simulateSwipe(detector: detector, axis: "x", positive: true)
        XCTAssertFalse(collector.events.isEmpty)
        XCTAssertEqual(detector.state, .idle)
    }

    // MARK: - Custom Configuration

    func testCustomThresholdWorks() {
        let config = SwipeDetectorConfig(activationThreshold: 2.0)
        let (detector, collector) = makeDetector(config: config)

        // Motion below custom threshold — should not activate
        for i in 0..<20 {
            let t = Double(i) * 0.01
            detector.processSample(x: 1.5, y: 0.01, z: 0.01, timestamp: t)
        }
        XCTAssertTrue(collector.events.isEmpty)

        // Motion above custom threshold
        simulateSwipe(detector: detector, axis: "x", positive: true, peakAccel: 3.0, startTime: 1.0)
        XCTAssertEqual(collector.events, [.swipeRight])
    }
}
