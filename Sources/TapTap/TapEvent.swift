import Foundation

/// Events emitted by the tap detector.
public enum TapEvent: Equatable, Sendable {
    case singleTap
    case doubleTap
    case longTap
}
