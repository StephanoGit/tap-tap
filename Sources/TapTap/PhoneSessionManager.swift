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
    /// Uses `sendMessage` for immediate delivery when reachable, and
    /// `updateApplicationContext` as a reliable fallback so the watch
    /// receives state even when not immediately reachable.
    ///
    /// Call this whenever ``ReplyManager/replies`` or
    /// ``ReplyManager/selectedIndex`` changes.
    /// Push the current reply state to the paired Apple Watch.
    ///
    /// After handling a gesture incoming from the watch we also include an
    /// optional `gestureAck` string; the watch uses that to flash the
    /// background and display a short label so the user can see that their tap
    /// actually went through. The method returns the dictionary that was sent
    /// so it can be inspected in unit tests.
    @discardableResult
    public func pushReplyState(gestureAck: String? = nil) -> [String: Any] {
        var state: [String: Any] = [
            "replies": ReplyManager.shared.replies,
            "selectedIndex": ReplyManager.shared.selectedIndex
        ]
        if let ack = gestureAck {
            state["gestureAck"] = ack
        }
        print("📱 Pushing reply state to watch: \(state)")

        // Immediate delivery when reachable
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(state, replyHandler: nil) { error in
                print("📱 Failed to push reply state via message: \(error.localizedDescription)")
            }
        }

        // Reliable fallback — delivered when watch next launches or becomes active
        do {
            try WCSession.default.updateApplicationContext(state)
        } catch {
            print("📱 Failed to update application context: \(error.localizedDescription)")
        }

        return state
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
