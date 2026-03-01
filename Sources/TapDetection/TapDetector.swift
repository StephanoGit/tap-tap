import Foundation

/// Pure signal-processing tap detector — no ML, no CoreMotion dependency.
///
/// Feed 3-axis user-acceleration samples (gravity already removed) via
/// ``processSample(x:y:z:timestamp:)`` and receive ``TapEvent`` values
/// through the ``onEvent`` callback.
///
/// ## Architecture
///
/// ```
/// IMU stream → magnitude → moving average → peak detection
///            → state machine → events (singleTap / doubleTap)
/// ```
///
/// The detector is **deterministic** and easy to tune at runtime via
/// ``TapDetectorConfiguration``.
public final class TapDetector {

    // MARK: - State

    /// Internal states for the tap-detection state machine.
    public enum State: Equatable, Sendable {
        /// Waiting for a tap.
        case idle
        /// A peak was detected; waiting to see if a second tap follows.
        case waitingForSecondTap
    }

    // MARK: - Public Properties

    /// Current detector configuration (tunable at runtime).
    public var configuration: TapDetectorConfiguration

    /// Callback invoked on the caller's thread whenever a tap event is detected.
    public var onEvent: ((TapEvent) -> Void)?

    /// The current state of the internal state machine (read-only, useful for debugging).
    public private(set) var state: State = .idle

    // MARK: - Internal State

    /// Ring buffer of recent magnitude values for the moving-average filter.
    private var magnitudeBuffer: [Double] = []

    /// Timestamp of the last trigger (used for lockout).
    private var lastTriggerTime: Double = -.greatestFiniteMagnitude

    /// Timestamp of the first tap while waiting for a potential double-tap.
    private var firstTapTime: Double?

    /// Pending single-tap work item (cancelled on double-tap).
    private var pendingSingleTap: DispatchWorkItem?

    // MARK: - Init

    /// Creates a new detector with the given configuration.
    public init(configuration: TapDetectorConfiguration = .init()) {
        self.configuration = configuration
    }

    // MARK: - Sample Processing

    /// Processes one accelerometer sample.
    ///
    /// - Parameters:
    ///   - x: X-axis user acceleration (g, gravity removed).
    ///   - y: Y-axis user acceleration (g, gravity removed).
    ///   - z: Z-axis user acceleration (g, gravity removed).
    ///   - timestamp: Sample timestamp in seconds (monotonic).
    public func processSample(x: Double, y: Double, z: Double, timestamp: Double) {
        let raw = SignalProcessor.magnitude(x: x, y: y, z: z)

        // Update magnitude ring buffer.
        magnitudeBuffer.append(raw)
        if magnitudeBuffer.count > configuration.movingAverageWindow {
            magnitudeBuffer.removeFirst()
        }

        let smoothed = SignalProcessor.movingAverage(
            buffer: magnitudeBuffer,
            windowSize: configuration.movingAverageWindow
        )

        // --- Lockout check ---
        if timestamp - lastTriggerTime < configuration.lockoutDuration {
            return
        }

        // --- Peak detection ---
        guard smoothed > configuration.tapThreshold else { return }

        lastTriggerTime = timestamp

        switch state {
        case .idle:
            // First tap detected.
            firstTapTime = timestamp
            state = .waitingForSecondTap
            scheduleSingleTapTimeout(tapTime: timestamp)

        case .waitingForSecondTap:
            if let first = firstTapTime,
               timestamp - first < configuration.doubleTapWindow {
                cancelPendingSingleTap()
                handleDoubleTap(timestamp: timestamp)
            } else {
                // Window expired but state wasn't cleaned up yet — treat as new first tap.
                cancelPendingSingleTap()
                emit(.singleTap)
                firstTapTime = timestamp
                state = .waitingForSecondTap
                scheduleSingleTapTimeout(tapTime: timestamp)
            }
        }
    }

    /// Resets the detector to its initial state, clearing all buffers and timers.
    public func reset() {
        cancelPendingSingleTap()
        resetState()
        magnitudeBuffer.removeAll()
        lastTriggerTime = -.greatestFiniteMagnitude
    }

    // MARK: - Synchronous Processing (for tests / non-DispatchQueue environments)

    /// Processes a sample and returns any emitted event **synchronously**.
    ///
    /// Unlike ``processSample(x:y:z:timestamp:)``, this variant does **not**
    /// use `DispatchQueue` for the single-tap timeout. Instead, the caller is
    /// responsible for calling ``flushPendingSingleTap(currentTime:)`` once
    /// the double-tap window has elapsed.
    ///
    /// - Returns: A ``TapEvent`` if one was emitted immediately, otherwise `nil`.
    @discardableResult
    public func processSampleSync(x: Double, y: Double, z: Double, timestamp: Double) -> TapEvent? {
        var emitted: TapEvent?
        let previous = onEvent
        onEvent = { event in
            emitted = event
            previous?(event)
        }
        processSampleSyncInternal(x: x, y: y, z: z, timestamp: timestamp)
        onEvent = previous
        return emitted
    }

    /// If a single-tap is pending and `currentTime` exceeds the double-tap
    /// window, emits the single tap.
    @discardableResult
    public func flushPendingSingleTap(currentTime: Double) -> TapEvent? {
        guard let first = firstTapTime,
              currentTime - first >= configuration.doubleTapWindow,
              state == .waitingForSecondTap else {
            return nil
        }
        firstTapTime = nil
        state = .idle
        let event = TapEvent.singleTap
        onEvent?(event)
        return event
    }

    // MARK: - Private Helpers

    private func processSampleSyncInternal(x: Double, y: Double, z: Double, timestamp: Double) {
        let raw = SignalProcessor.magnitude(x: x, y: y, z: z)

        magnitudeBuffer.append(raw)
        if magnitudeBuffer.count > configuration.movingAverageWindow {
            magnitudeBuffer.removeFirst()
        }

        let smoothed = SignalProcessor.movingAverage(
            buffer: magnitudeBuffer,
            windowSize: configuration.movingAverageWindow
        )

        // --- Lockout ---
        if timestamp - lastTriggerTime < configuration.lockoutDuration {
            return
        }

        guard smoothed > configuration.tapThreshold else { return }

        lastTriggerTime = timestamp

        switch state {
        case .idle:
            firstTapTime = timestamp
            state = .waitingForSecondTap

        case .waitingForSecondTap:
            if let first = firstTapTime,
               timestamp - first < configuration.doubleTapWindow {
                handleDoubleTap(timestamp: timestamp)
            } else {
                emit(.singleTap)
                firstTapTime = timestamp
                state = .waitingForSecondTap
            }
        }
    }

    private func handleDoubleTap(timestamp: Double) {
        firstTapTime = nil
        state = .idle
        emit(.doubleTap)
    }

    private func emit(_ event: TapEvent) {
        onEvent?(event)
    }

    private func resetState() {
        state = .idle
        firstTapTime = nil
    }

    private func scheduleSingleTapTimeout(tapTime: Double) {
        cancelPendingSingleTap()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.firstTapTime == tapTime else { return }
            self.firstTapTime = nil
            self.state = .idle
            self.emit(.singleTap)
        }
        pendingSingleTap = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + configuration.doubleTapWindow,
            execute: item
        )
    }

    private func cancelPendingSingleTap() {
        pendingSingleTap?.cancel()
        pendingSingleTap = nil
    }
}
