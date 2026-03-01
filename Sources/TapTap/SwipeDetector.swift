import Foundation

/// Configuration for the swipe detector. All time values are in seconds.
public struct SwipeDetectorConfig: Sendable {
    /// Minimum acceleration on a single axis (in g) to begin tracking a swipe.
    public var activationThreshold: Double

    /// Maximum duration of a swipe gesture from start to end.
    public var maxSwipeDuration: TimeInterval

    /// Minimum ratio of dominant-axis displacement to the largest
    /// non-dominant axis displacement. Ensures the gesture is clearly
    /// directional rather than diagonal or random noise.
    public var axisRatio: Double

    /// Minimum absolute integrated velocity (displacement proxy) on the
    /// dominant axis for the gesture to count as a swipe.
    public var minDisplacement: Double

    /// Cooldown after a detected swipe during which new swipes are ignored.
    public var cooldown: TimeInterval

    public init(
        activationThreshold: Double = 0.4,
        maxSwipeDuration: TimeInterval = 0.500,
        axisRatio: Double = 1.5,
        minDisplacement: Double = 0.06,
        cooldown: TimeInterval = 0.300
    ) {
        self.activationThreshold = activationThreshold
        self.maxSwipeDuration = maxSwipeDuration
        self.axisRatio = axisRatio
        self.minDisplacement = minDisplacement
        self.cooldown = cooldown
    }
}

/// Pure signal-processing swipe detector.
///
/// Feed it user-acceleration samples (gravity already removed) via
/// ``processSample(x:y:z:timestamp:)`` and receive ``SwipeEvent`` values
/// through the ``onSwipe`` callback.
///
/// **Detection algorithm:**
///
/// 1. When acceleration on any single axis exceeds `activationThreshold`,
///    start recording samples.
/// 2. Integrate per-axis acceleration over time to estimate velocity.
/// 3. When the dominant-axis velocity crosses zero (deceleration complete)
///    or the gesture times out, evaluate:
///    - Dominant axis must have `minDisplacement` of integrated movement.
///    - Dominant axis displacement must exceed the next-largest axis by
///      `axisRatio`.
/// 4. The sign and axis of the dominant displacement determine the
///    ``SwipeDirection``.
///
/// Axis mapping (Apple Watch, hand pointing forward):
/// - **X axis** → horizontal: positive = rightward, negative = leftward
/// - **Y axis** → vertical (inverted): positive = downward, negative = upward
public final class SwipeDetector {

    // MARK: - State

    public enum State: Equatable, Sendable {
        case idle
        case tracking
    }

    public private(set) var state: State = .idle

    public var config: SwipeDetectorConfig

    /// Callback invoked whenever a swipe event is detected.
    public var onSwipe: ((SwipeEvent) -> Void)?

    // MARK: - Internal tracking

    private struct Sample {
        let x: Double
        let y: Double
        let z: Double
        let timestamp: TimeInterval
    }

    private var samples: [Sample] = []
    private var trackingStartTime: TimeInterval?
    private var lastSwipeTime: TimeInterval = -.infinity

    // Integrated velocity per axis (trapezoidal integration)
    private var velocityX: Double = 0
    private var velocityY: Double = 0
    private var velocityZ: Double = 0

    // MARK: - Init

    public init(config: SwipeDetectorConfig = SwipeDetectorConfig()) {
        self.config = config
    }

    // MARK: - Public API

    /// Feed a user-acceleration sample (gravity removed).
    ///
    /// - Parameters:
    ///   - x: X-axis acceleration in g.
    ///   - y: Y-axis acceleration in g.
    ///   - z: Z-axis acceleration in g.
    ///   - timestamp: Sample timestamp in seconds (monotonic).
    public func processSample(x: Double, y: Double, z: Double, timestamp: TimeInterval) {
        // Cooldown check
        if timestamp - lastSwipeTime < config.cooldown {
            return
        }

        switch state {
        case .idle:
            // Check if any single axis exceeds activation threshold
            if abs(x) >= config.activationThreshold ||
               abs(y) >= config.activationThreshold ||
               abs(z) >= config.activationThreshold {
                state = .tracking
                trackingStartTime = timestamp
                samples = [Sample(x: x, y: y, z: z, timestamp: timestamp)]
                velocityX = 0
                velocityY = 0
                velocityZ = 0
            }

        case .tracking:
            guard let startTime = trackingStartTime else {
                state = .idle
                return
            }

            let elapsed = timestamp - startTime

            // Timeout — evaluate what we have
            if elapsed > config.maxSwipeDuration {
                evaluateAndEmit(timestamp: timestamp)
                return
            }

            // Integrate acceleration into velocity (trapezoidal rule)
            if let prev = samples.last {
                let dt = timestamp - prev.timestamp
                if dt > 0 {
                    velocityX += (prev.x + x) / 2.0 * dt
                    velocityY += (prev.y + y) / 2.0 * dt
                    velocityZ += (prev.z + z) / 2.0 * dt
                }
            }

            samples.append(Sample(x: x, y: y, z: z, timestamp: timestamp))

            // Check for velocity zero-crossing on the dominant axis
            // (indicates the acceleration → deceleration cycle is complete)
            if samples.count >= 3 {
                let dominant = dominantAxis()
                let currentVelocity: Double
                switch dominant {
                case .x: currentVelocity = velocityX
                case .y: currentVelocity = velocityY
                case .z: currentVelocity = velocityZ
                }

                // If the dominant axis accumulated enough displacement and
                // velocity is starting to reverse, evaluate
                let displacement = abs(currentVelocity)
                if displacement >= config.minDisplacement {
                    // Check if the last two acceleration samples show a sign change
                    // (deceleration phase)
                    let n = samples.count
                    let prev = samples[n - 2]
                    let curr = samples[n - 1]
                    let prevAccel: Double
                    let currAccel: Double
                    switch dominant {
                    case .x: prevAccel = prev.x; currAccel = curr.x
                    case .y: prevAccel = prev.y; currAccel = curr.y
                    case .z: prevAccel = prev.z; currAccel = curr.z
                    }

                    // Sign change in acceleration = deceleration started
                    if prevAccel * currAccel < 0 || abs(currAccel) < config.activationThreshold * 0.3 {
                        evaluateAndEmit(timestamp: timestamp)
                        return
                    }
                }
            }
        }
    }

    /// Reset the detector to its initial state.
    public func reset() {
        state = .idle
        samples.removeAll()
        trackingStartTime = nil
        velocityX = 0
        velocityY = 0
        velocityZ = 0
        lastSwipeTime = -.infinity
    }

    // MARK: - Internal

    private enum Axis {
        case x, y, z
    }

    private func dominantAxis() -> Axis {
        let absX = abs(velocityX)
        let absY = abs(velocityY)
        let absZ = abs(velocityZ)

        if absX >= absY && absX >= absZ { return .x }
        if absY >= absX && absY >= absZ { return .y }
        return .z
    }

    /// Exposed for testing.
    func evaluateAndEmit(timestamp: TimeInterval) {
        defer { resetTracking() }

        let absX = abs(velocityX)
        let absY = abs(velocityY)
        let absZ = abs(velocityZ)

        // Find dominant axis and its displacement
        let dominant = dominantAxis()
        let dominantDisplacement: Double
        let dominantVelocity: Double
        let secondLargest: Double

        switch dominant {
        case .x:
            dominantDisplacement = absX
            dominantVelocity = velocityX
            secondLargest = max(absY, absZ)
        case .y:
            dominantDisplacement = absY
            dominantVelocity = velocityY
            secondLargest = max(absX, absZ)
        case .z:
            dominantDisplacement = absZ
            dominantVelocity = velocityZ
            secondLargest = max(absX, absY)
        }

        // Must meet minimum displacement
        guard dominantDisplacement >= config.minDisplacement else { return }

        // Must be clearly directional (dominant axis >> others)
        if secondLargest > 0 {
            guard dominantDisplacement / secondLargest >= config.axisRatio else { return }
        }

        // Z-axis swipes are not mapped to any direction
        // (only X and Y are meaningful for horizontal/vertical)
        let direction: SwipeDirection
        switch dominant {
        case .x:
            direction = dominantVelocity > 0 ? .right : .left
        case .y:
            direction = dominantVelocity > 0 ? .down : .up
        case .z:
            return // Ignore z-dominant gestures
        }

        lastSwipeTime = timestamp
        onSwipe?(.swipe(direction))
    }

    private func resetTracking() {
        state = .idle
        samples.removeAll()
        trackingStartTime = nil
        velocityX = 0
        velocityY = 0
        velocityZ = 0
    }
}
