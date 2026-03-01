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

    // MARK: - WCSessionDelegate

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let gesture = message[GestureRouter.gestureKey] as? String {
            GestureRouter.shared.handle(gesture)
        }
    }
}
#endif
