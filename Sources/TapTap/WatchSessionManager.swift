#if os(watchOS)
import Foundation
import WatchConnectivity

/// Manages the WatchConnectivity session on the Apple Watch side.
///
/// Activates `WCSession` on init and provides a single method to send
/// gesture strings to the paired iPhone. Also receives reply state
/// pushed from the iPhone (replies array and selectedIndex).
///
/// Usage:
/// ```swift
/// // Activate early (e.g. in App init or ExtensionDelegate)
/// _ = WatchSessionManager.shared
///
/// // Send a detected gesture
/// WatchSessionManager.shared.send("singleTap")
///
/// // Observe reply state
/// WatchSessionManager.shared.onReplyStateChanged = { replies, index in
///     // update UI
/// }
/// ```
public final class WatchSessionManager: NSObject, WCSessionDelegate {

    /// Shared singleton instance. Activates the WCSession on first access.
    public static let shared = WatchSessionManager()

    /// Message key used for gesture payloads between Watch and Phone.
    static let gestureKey = GestureRouter.gestureKey

    /// The replies received from the paired iPhone.
    public private(set) var replies: [String] = []

    /// The currently selected index received from the paired iPhone.
    public private(set) var selectedIndex: Int = 0

    /// The currently selected reply string, or `nil` if replies is empty.
    public var selectedReply: String? {
        guard !replies.isEmpty, selectedIndex < replies.count else { return nil }
        return replies[selectedIndex]
    }

    /// Callback invoked when the iPhone pushes updated reply state.
    /// Called on the WatchConnectivity delegate queue — dispatch to main
    /// if updating UI.
    public var onReplyStateChanged: (([String], Int) -> Void)?

    /// Callback invoked when a gesture acknowledgment is received
    /// (e.g. for UI feedback like "sent" confirmation).
    public var onGestureAck: ((String) -> Void)?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// Load any existing application context that was set before launch.
    /// Call this after setting ``onReplyStateChanged`` to receive the
    /// initial state.
    public func loadCachedState() {
        let ctx = WCSession.default.receivedApplicationContext
        if !ctx.isEmpty {
            print("⌚ Loading cached application context: \(ctx)")
            handleReplyState(ctx)
        }
    }

    /// Send a gesture string to the paired iPhone.
    ///
    /// On watchOS, `sendMessage` wakes up the iOS companion app even when
    /// it is not in the foreground, so no reachability guard is needed.
    ///
    /// - Parameter gesture: One of `"singleTap"`, `"doubleTap"`, `"longTap"`,
    ///   `"swipeUp"`, `"swipeDown"`, `"swipeLeft"`, `"swipeRight"`.
    public func send(_ gesture: String) {
        guard WCSession.default.activationState == .activated else {
            print("⌚ Session not activated, dropping gesture: \(gesture)")
            return
        }
        print("⌚ Sending gesture: \(gesture)")
        WCSession.default.sendMessage([Self.gestureKey: gesture], replyHandler: nil) { error in
            print("⌚ Failed to send gesture \(gesture): \(error.localizedDescription)")
        }
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

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("⌚ Received message from phone: \(message)")
        handleReplyState(message)
    }

    /// Handle application context updates (reliable fallback delivery).
    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("⌚ Received application context from phone: \(applicationContext)")
        handleReplyState(applicationContext)
    }

    /// Parse reply state from a dictionary and update local state.
    private func handleReplyState(_ data: [String: Any]) {
        // Handle reply state updates from iPhone
        if let newReplies = data["replies"] as? [String],
           let newIndex = data["selectedIndex"] as? Int {
            replies = newReplies
            selectedIndex = newIndex
            onReplyStateChanged?(replies, selectedIndex)
        }

        // Handle gesture acknowledgments
        if let gestureAck = data["gestureAck"] as? String {
            onGestureAck?(gestureAck)
        }
    }
}
#endif
