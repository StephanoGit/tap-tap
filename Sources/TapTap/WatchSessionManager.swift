#if os(watchOS)
import Foundation
import WatchConnectivity

/// Manages the WatchConnectivity session on the Apple Watch side.
///
/// Activates `WCSession` on init and provides a single method to send
/// gesture strings to the paired iPhone.
///
/// Usage:
/// ```swift
/// // Activate early (e.g. in App init or ExtensionDelegate)
/// _ = WatchSessionManager.shared
///
/// // Send a detected gesture
/// WatchSessionManager.shared.send("singleTap")
/// ```
public final class WatchSessionManager: NSObject, WCSessionDelegate {

    /// Shared singleton instance. Activates the WCSession on first access.
    public static let shared = WatchSessionManager()

    /// Message key used for gesture payloads between Watch and Phone.
    static let gestureKey = GestureRouter.gestureKey

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// Send a gesture string to the paired iPhone.
    ///
    /// - Parameter gesture: One of `"singleTap"`, `"doubleTap"`, `"longTap"`,
    ///   `"swipeUp"`, `"swipeDown"`, `"swipeLeft"`, `"swipeRight"`.
    public func send(_ gesture: String) {
        guard WCSession.default.isReachable else { return }
        print("⌚ Sending gesture: \(gesture)")
        WCSession.default.sendMessage([Self.gestureKey: gesture], replyHandler: nil, errorHandler: nil)
    }

    // MARK: - WCSessionDelegate

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        print("⌚ Watch session activated: \(activationState.rawValue)")
        if let error = error {
            print("⌚ Watch session activation error: \(error.localizedDescription)")
        }
    }
}
#endif
