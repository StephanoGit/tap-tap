#if os(watchOS)
import SwiftUI

/// watchOS SwiftUI view that displays the current reply from the iPhone.
///
/// - Receives reply state from ``WatchSessionManager``
/// - Shows current reply text large and centered
/// - Index indicator "1 / 3" at bottom
/// - Dark grey background normally
/// - Blue flash & "Tap" label when a tap gesture is registered
/// - Green flash & "Double Tap" label when a double tap is registered
/// - "Sent!" overlay for send confirmations (double tap/swipe up)
/// - "Waiting..." when replies is empty
///
/// Usage in the Watch App entry point:
/// ```swift
/// @main
/// struct TapTapWatchApp: App {
///     init() {
///         _ = WatchSessionManager.shared
///     }
///     var body: some Scene {
///         WindowGroup {
///             WatchContentView()
///         }
///     }
/// }
/// ```
public struct WatchContentView: View {

    @StateObject private var viewModel = WatchReplyViewModel()

    public init() {}

    public var body: some View {
        ZStack {
            viewModel.backgroundColor.ignoresSafeArea()

            if viewModel.replies.isEmpty {
                Text("Waiting...")
                    .font(.headline)
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 8) {
                    Spacer()

                    Text(viewModel.currentReply)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Spacer()

                    Text("\(viewModel.selectedIndex + 1) / \(viewModel.replies.count)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 4)
                }
            }

            // "Sent!" overlay (used for send confirmations)
            if viewModel.showSentConfirmation {
                Text("✓ Sent")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.9))
                    .cornerRadius(10)
            }

            // Feedback label for tap/double‑tap gestures
            if let label = viewModel.gestureLabel {
                Text(label)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
            }
        }
        // support screen taps so the watch can drive the reply index locally
        .gesture(
            TapGesture(count: 2)
                .onEnded { _ in
                    viewModel.handleLocalGesture("doubleTap")
                }
                // single‑tap handler runs if the double‑tap fails
                .exclusively(before: TapGesture().onEnded { _ in
                    viewModel.handleLocalGesture("singleTap")
                })
    }
}

/// ViewModel for the Watch reply display.
///
/// Listens to ``WatchSessionManager`` callbacks for reply state
/// updates and gesture acknowledgments.
public final class WatchReplyViewModel: ObservableObject {
    @Published public var replies: [String] = []
    @Published public var selectedIndex: Int = 0
    @Published public var showSentConfirmation: Bool = false

    /// Label to display temporarily when a gesture occurs ("Tap", "Double Tap",
    /// "Sent!", etc.). Nil when nothing should be shown.
    @Published public var gestureLabel: String?

    /// The current reply text to display.
    public var currentReply: String {
        guard !replies.isEmpty, selectedIndex < replies.count else { return "" }
        return replies[selectedIndex]
    }

    /// Background color based on state or recent gesture.
    public var backgroundColor: Color {
        // send confirmation (double‑tap or swipeUp)
        if showSentConfirmation { return .green.opacity(0.3) }
        // feedback from the last gesture label
        if let label = gestureLabel {
            switch label {
            case "Tap": return .blue.opacity(0.4)
            case "Double Tap": return .green.opacity(0.4)
            default: break
            }
        }
        return Color(white: 0.15)
    }

    private var timer: Timer?

    public init() {
        // Listen for reply state pushed from iPhone
        WatchSessionManager.shared.onReplyStateChanged = { [weak self] newReplies, newIndex in
            DispatchQueue.main.async {
                self?.replies = newReplies
                self?.selectedIndex = newIndex
            }
        }

        // Listen for gesture acks (for visual feedback)
        WatchSessionManager.shared.onGestureAck = { [weak self] gesture in
            DispatchQueue.main.async {
                self?.handleGestureAck(gesture)
            }
        }

        // Load any cached application context from before launch
        WatchSessionManager.shared.loadCachedState()

        // Also poll WatchSessionManager state at 10 Hz as fallback
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.syncState()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func syncState() {
        let mgr = WatchSessionManager.shared
        if mgr.replies != replies {
            replies = mgr.replies
        }
        if mgr.selectedIndex != selectedIndex {
            selectedIndex = mgr.selectedIndex
        }
    }

    /// Handle a gesture acknowledgement coming from the phone. This is called
    /// indirectly via ``WatchSessionManager/onGestureAck``. We use the same
    /// styling logic for local gestures (see ``handleLocalGesture(_:)``) so the
    /// user sees feedback even if the phone takes a moment to respond.
    func handleGestureAck(_ gesture: String) {
        switch gesture {
        case "singleTap":
            gestureLabel = "Tap"
            clearGestureLabel(after: 1.0)
        case "doubleTap":
            gestureLabel = "Double Tap"
            showSentConfirmation = true
            clearGestureLabel(after: 1.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.showSentConfirmation = false
            }
        case "swipeUp":
            // older behaviour – keep for compatibility
            gestureLabel = "Sent!"
            showSentConfirmation = true
            clearGestureLabel(after: 1.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.showSentConfirmation = false
            }
        default:
            break
        }
    }

    /// Called by the view when the user taps/double‑taps the screen. The
    /// gesture is forwarded to the phone and we also update local state
    /// immediately so the UI feels snappy even if the phone is slow or
    /// unreachable.
    func handleLocalGesture(_ gesture: String) {
        // local selection logic for tap (cycles replies)
        switch gesture {
        case "singleTap":
            if !replies.isEmpty {
                selectedIndex = min(selectedIndex + 1, replies.count - 1)
            }
        default:
            break
        }

        // show the same feedback as an acknowledgement
        handleGestureAck(gesture)

        // forward to phone
        WatchSessionManager.shared.send(gesture)
    }

    private func clearGestureLabel(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.gestureLabel = nil
        }
    }
}
#endif
