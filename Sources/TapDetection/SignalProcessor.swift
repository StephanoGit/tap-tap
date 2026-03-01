import Foundation

/// Lightweight signal processing helpers for IMU data.
///
/// All functions are pure — no internal state.
public enum SignalProcessor {

    // MARK: - Magnitude

    /// Computes the Euclidean magnitude of a 3-axis acceleration sample.
    ///
    /// When using `CMAcceleration.userAcceleration` (gravity already removed),
    /// the result approximates the acceleration magnitude in *g*.
    ///
    /// - Parameters:
    ///   - x: X-axis acceleration.
    ///   - y: Y-axis acceleration.
    ///   - z: Z-axis acceleration.
    /// - Returns: `sqrt(x² + y² + z²)`
    public static func magnitude(x: Double, y: Double, z: Double) -> Double {
        (x * x + y * y + z * z).squareRoot()
    }

    // MARK: - Moving Average

    /// Applies a simple moving average to the given signal buffer.
    ///
    /// - Parameters:
    ///   - buffer: Ring buffer of recent magnitude samples (oldest first).
    ///   - windowSize: Number of samples to average.
    /// - Returns: The mean of the last `windowSize` elements, or of all
    ///   elements if the buffer is shorter.
    public static func movingAverage(buffer: [Double], windowSize: Int) -> Double {
        guard !buffer.isEmpty else { return 0 }
        let count = min(windowSize, buffer.count)
        let slice = buffer.suffix(count)
        return slice.reduce(0, +) / Double(count)
    }
}
