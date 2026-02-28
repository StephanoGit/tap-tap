import Foundation

/// Configuration for the tap detector. All time values are in seconds.
public struct TapDetectorConfig: Sendable {
    /// Minimum acceleration magnitude (in g) to register a peak.
    public var threshold: Double

    /// Time after a detected peak during which further peaks are ignored,
    /// preventing ringing oscillations from being counted as extra taps.
    public var lockoutInterval: TimeInterval

    /// Maximum time between two taps to classify them as a double tap.
    public var doubleTapWindow: TimeInterval

    /// Duration of sustained low-variance acceleration required after a peak
    /// to classify the gesture as a long tap.
    public var longTapHoldDuration: TimeInterval

    /// Maximum magnitude variance during the hold window for long-tap detection.
    public var longTapVarianceThreshold: Double

    public init(
        threshold: Double = 1.5,
        lockoutInterval: TimeInterval = 0.120,
        doubleTapWindow: TimeInterval = 0.350,
        longTapHoldDuration: TimeInterval = 0.500,
        longTapVarianceThreshold: Double = 0.05
    ) {
        self.threshold = threshold
        self.lockoutInterval = lockoutInterval
        self.doubleTapWindow = doubleTapWindow
        self.longTapHoldDuration = longTapHoldDuration
        self.longTapVarianceThreshold = longTapVarianceThreshold
    }
}

/// Pure signal-processing tap detector.
///
/// Feed it user-acceleration samples (gravity already removed) via
/// ``processSample(x:y:z:timestamp:)`` and receive ``TapEvent`` values
/// through the ``onTap`` callback.
///
/// The detector implements a minimal state machine:
///
/// ```
/// IDLE → TAP_DETECTED → WAITING_FOR_SECOND_TAP
///                           ├─ second tap within window  → doubleTap
///                           └─ timeout                   → singleTap
/// ```
///
/// Long-tap detection works by monitoring acceleration variance after a
/// peak: if variance stays below a threshold for `longTapHoldDuration`,
/// a ``TapEvent/longTap`` is emitted instead of a single tap.
public final class TapDetector {

    // MARK: - State

    public enum State: Equatable, Sendable {
        case idle
        case tapDetected
        case waitingForSecondTap
    }

    public private(set) var state: State = .idle

    public var config: TapDetectorConfig

    /// Callback invoked on the caller's thread whenever a tap event is detected.
    public var onTap: ((TapEvent) -> Void)?

    // MARK: - Internal timing

    private var lastTriggerTime: TimeInterval = -.infinity
    private var firstTapTime: TimeInterval?

    // Long-tap tracking
    private var holdSamples: [(magnitude: Double, timestamp: TimeInterval)] = []
    private var holdStartTime: TimeInterval?

    // Pending single-tap timer (for deferred emission)
    private var pendingTimer: DispatchWorkItem?

    // MARK: - Init

    public init(config: TapDetectorConfig = TapDetectorConfig()) {
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
        let magnitude = sqrt(x * x + y * y + z * z)
        processMagnitude(magnitude, timestamp: timestamp)
    }

    /// Reset the detector to its initial state, cancelling any pending timers.
    public func reset() {
        state = .idle
        lastTriggerTime = -.infinity
        firstTapTime = nil
        holdSamples.removeAll()
        holdStartTime = nil
        pendingTimer?.cancel()
        pendingTimer = nil
    }

    // MARK: - Core detection

    /// Process a single magnitude sample. Exposed internally for testing.
    func processMagnitude(_ magnitude: Double, timestamp: TimeInterval) {
        // --- Long-tap hold tracking ---
        if let start = holdStartTime {
            holdSamples.append((magnitude, timestamp))

            if magnitude > config.threshold {
                // Another spike during hold — abort long-tap tracking,
                // this will be handled as a potential double tap below.
                holdSamples.removeAll()
                holdStartTime = nil
            } else if timestamp - start >= config.longTapHoldDuration {
                let variance = self.variance(of: holdSamples.map(\.magnitude))
                if variance <= config.longTapVarianceThreshold {
                    cancelPendingTimer()
                    emit(.longTap)
                    firstTapTime = nil
                    holdSamples.removeAll()
                    holdStartTime = nil
                    state = .idle
                    return
                }
                // Variance too high — not a long tap, fall through.
                holdSamples.removeAll()
                holdStartTime = nil
            } else {
                return // Still accumulating hold samples
            }
        }

        // --- Lockout ---
        if timestamp - lastTriggerTime < config.lockoutInterval {
            return
        }

        // --- Peak detection ---
        guard magnitude > config.threshold else { return }

        lastTriggerTime = timestamp

        // --- State machine ---
        switch state {
        case .idle:
            firstTapTime = timestamp
            state = .waitingForSecondTap
            startHoldTracking(at: timestamp)
            scheduleSingleTapTimeout(tapTime: timestamp)

        case .tapDetected, .waitingForSecondTap:
            if let first = firstTapTime, timestamp - first < config.doubleTapWindow {
                cancelPendingTimer()
                emit(.doubleTap)
                firstTapTime = nil
                holdSamples.removeAll()
                holdStartTime = nil
                state = .idle
            } else {
                // Outside double-tap window — treat as new first tap.
                firstTapTime = timestamp
                state = .waitingForSecondTap
                startHoldTracking(at: timestamp)
                scheduleSingleTapTimeout(tapTime: timestamp)
            }
        }
    }

    // MARK: - Helpers

    private func startHoldTracking(at timestamp: TimeInterval) {
        holdSamples.removeAll()
        holdStartTime = timestamp
    }

    private func scheduleSingleTapTimeout(tapTime: TimeInterval) {
        cancelPendingTimer()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.firstTapTime == tapTime {
                self.emit(.singleTap)
                self.firstTapTime = nil
                self.state = .idle
            }
        }
        pendingTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + config.doubleTapWindow, execute: item)
    }

    private func cancelPendingTimer() {
        pendingTimer?.cancel()
        pendingTimer = nil
    }

    private func emit(_ event: TapEvent) {
        onTap?(event)
    }

    /// Simple variance calculation.
    func variance(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSquaredDiff = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return sumSquaredDiff / Double(values.count)
    }
}
