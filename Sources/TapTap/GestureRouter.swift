import Foundation

/// Routes gesture strings received from the Apple Watch to a handler callback.
///
/// ``PhoneSessionManager`` calls ``handle(_:)`` when it receives a gesture
/// message over WatchConnectivity. Set ``onGesture`` to react to incoming
/// gestures on the iPhone side.
///
/// Usage:
/// ```swift
/// GestureRouter.shared.onGesture = { gesture in
///     switch gesture {
///     case "singleTap":  print("tap")
///     case "doubleTap":  print("double tap")
///     case "longTap":    print("long tap")
///     case "swipeLeft":  print("swipe left")
///     case "swipeRight": print("swipe right")
///     case "swipeUp":    print("swipe up")
///     case "swipeDown":  print("swipe down")
///     default:           break
///     }
/// }
/// ```
public final class GestureRouter {

    /// Shared singleton instance.
    public static let shared = GestureRouter()

    /// Message key used for gesture payloads in WatchConnectivity messages.
    public static let gestureKey = "gesture"

    /// Callback invoked when a gesture string is received from the watch.
    /// Called on the WatchConnectivity delegate queue — dispatch to main
    /// if updating UI.
    public var onGesture: ((String) -> Void)?

    private init() {}

    /// Handle an incoming gesture string.
    ///
    /// Routes gestures to ``ReplyManager/shared`` actions:
    /// - `"singleTap"` → `selectNext()` (tap to cycle through replies)
    /// - `"swipeUp"` → `sendSelected()` (swipe up to confirm/send)
    /// - `"swipeDown"` → `selectPrevious()`
    /// - `"swipeLeft"` → `reset()`
    /// - `"doubleTap"` → prints the selected index
    ///
    /// After handling, immediately pushes updated reply state to the watch
    /// via ``PhoneSessionManager`` and invokes the ``onGesture`` callback.
    ///
    /// - Parameter gesture: The gesture identifier (e.g. `"singleTap"`).
    public func handle(_ gesture: String) {
        switch gesture {
        case "singleTap", "doubleTap":
            // both tap variants cycle to the next reply so that the watch UI
            // always advances regardless of whether the user single‑ or
            // double‑taps the screen.
            ReplyManager.shared.selectNext()
        case "swipeUp":
            ReplyManager.shared.sendSelected()
        case "swipeDown":
            ReplyManager.shared.selectPrevious()
        case "swipeLeft":
            ReplyManager.shared.reset()
        default:
            break
        }

        // Push updated state to watch immediately, including a gesture
        // acknowledgement so the watch can display feedback.
        #if os(iOS)
        PhoneSessionManager.shared.pushReplyState(gestureAck: gesture)
        #endif

        onGesture?(gesture)
    }
}
