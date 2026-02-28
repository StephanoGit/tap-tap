import Foundation

/// Direction of a detected swipe gesture.
public enum SwipeDirection: Equatable, Sendable {
    case left
    case right
    case up
    case down
}

/// Events emitted by the swipe detector.
public enum SwipeEvent: Equatable, Sendable {
    case swipe(SwipeDirection)

    public static let swipeLeft  = SwipeEvent.swipe(.left)
    public static let swipeRight = SwipeEvent.swipe(.right)
    public static let swipeUp    = SwipeEvent.swipe(.up)
    public static let swipeDown  = SwipeEvent.swipe(.down)
}
