/// Events emitted by the tap detector.
public enum TapEvent: Equatable, Sendable {
    /// A single tap was detected.
    case singleTap
    /// Two taps in quick succession were detected.
    case doubleTap
    /// A tap followed by sustained contact was detected.
    case longTap
}
