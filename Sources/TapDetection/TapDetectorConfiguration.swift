/// Tunable parameters for `TapDetector`.
///
/// Default values are chosen for Apple Watch Series 7 at ~100 Hz.
public struct TapDetectorConfiguration: Sendable {

    // MARK: - Signal Processing

    /// Number of samples for the moving-average smoothing window.
    /// A small window (3–5) preserves sharp spikes while removing noise.
    public var movingAverageWindow: Int

    // MARK: - Peak Detection

    /// Minimum acceleration magnitude (in g) to recognise a peak as a tap.
    public var tapThreshold: Double

    /// Minimum time (seconds) after a detected tap before another can fire.
    /// Prevents ringing oscillations from producing duplicate events.
    public var lockoutDuration: Double

    // MARK: - Double-Tap

    /// Maximum time (seconds) between two taps to classify them as a double-tap.
    public var doubleTapWindow: Double

    // MARK: - Long-Tap

    /// Maximum magnitude (in g) during the hold phase for it to count as "still".
    public var longTapHoldThreshold: Double

    /// Minimum hold duration (seconds) after the initial spike to classify as long-tap.
    public var longTapHoldDuration: Double

    /// Creates a configuration with the given parameters.
    public init(
        movingAverageWindow: Int = 3,
        tapThreshold: Double = 1.5,
        lockoutDuration: Double = 0.120,
        doubleTapWindow: Double = 0.350,
        longTapHoldThreshold: Double = 0.3,
        longTapHoldDuration: Double = 0.500
    ) {
        self.movingAverageWindow = movingAverageWindow
        self.tapThreshold = tapThreshold
        self.lockoutDuration = lockoutDuration
        self.doubleTapWindow = doubleTapWindow
        self.longTapHoldThreshold = longTapHoldThreshold
        self.longTapHoldDuration = longTapHoldDuration
    }
}
