import XCTest
@testable import TapDetection

final class SignalProcessorTests: XCTestCase {

    // MARK: - Magnitude

    func testMagnitudeZeroVector() {
        XCTAssertEqual(SignalProcessor.magnitude(x: 0, y: 0, z: 0), 0, accuracy: 1e-9)
    }

    func testMagnitudeUnitAxes() {
        XCTAssertEqual(SignalProcessor.magnitude(x: 1, y: 0, z: 0), 1, accuracy: 1e-9)
        XCTAssertEqual(SignalProcessor.magnitude(x: 0, y: 1, z: 0), 1, accuracy: 1e-9)
        XCTAssertEqual(SignalProcessor.magnitude(x: 0, y: 0, z: 1), 1, accuracy: 1e-9)
    }

    func testMagnitude3D() {
        // |<1,2,2>| = 3
        XCTAssertEqual(SignalProcessor.magnitude(x: 1, y: 2, z: 2), 3, accuracy: 1e-9)
    }

    func testMagnitudeNegativeValues() {
        let m = SignalProcessor.magnitude(x: -1, y: -2, z: -2)
        XCTAssertEqual(m, 3, accuracy: 1e-9)
    }

    // MARK: - Moving Average

    func testMovingAverageEmptyBuffer() {
        XCTAssertEqual(SignalProcessor.movingAverage(buffer: [], windowSize: 3), 0, accuracy: 1e-9)
    }

    func testMovingAverageSmallBuffer() {
        // Buffer smaller than window — average all elements.
        let avg = SignalProcessor.movingAverage(buffer: [2, 4], windowSize: 5)
        XCTAssertEqual(avg, 3, accuracy: 1e-9)
    }

    func testMovingAverageExactWindow() {
        let avg = SignalProcessor.movingAverage(buffer: [1, 2, 3], windowSize: 3)
        XCTAssertEqual(avg, 2, accuracy: 1e-9)
    }

    func testMovingAverageLargerBuffer() {
        // Only the last 3 elements should be used.
        let avg = SignalProcessor.movingAverage(buffer: [100, 1, 2, 3], windowSize: 3)
        XCTAssertEqual(avg, 2, accuracy: 1e-9)
    }
}
