#if os(iOS)
import Foundation
import WatchConnectivity

/// Manages the WatchConnectivity session on the iPhone side.
///
/// Activates `WCSession` on init, sets itself as delegate, and forwards
/// received gesture messages to ``GestureRouter/shared``.
///
/// Usage:
/// ```swift
/// // Activate early (e.g. in App init or AppDelegate)
/// _ = PhoneSessionManager.shared
/// ```
public final class PhoneSessionManager: NSObject, WCSessionDelegate {

    /// Shared singleton instance. Activates the WCSession on first access.
    public static let shared = PhoneSessionManager()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// Push the current reply state to the paired Apple Watch.
    ///
    /// Sends `["replies": [...], "selectedIndex": Int]` via `sendMessage`.
    /// Call this whenever ``ReplyManager/replies`` or
    /// ``ReplyManager/selectedIndex`` changes.
    public func pushReplyState() {
        guard WCSession.default.isReachable else { return }
        let state: [String: Any] = [
            "replies": ReplyManager.shared.replies,
            "selectedIndex": ReplyManager.shared.selectedIndex
        ]
        print("📱 Pushing reply state to watch: \(state)")
        WCSession.default.sendMessage(state, replyHandler: nil) { error in
            print("📱 Failed to push reply state: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        print("📱 Phone session activated: \(activationState.rawValue)")
        if let error = error {
            print("📱 Phone session activation error: \(error.localizedDescription)")
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("📱 Received gesture: \(message)")
        if let gesture = message[GestureRouter.gestureKey] as? String {
            GestureRouter.shared.handle(gesture)
        }
    }
}
#endif
