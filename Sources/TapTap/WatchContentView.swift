#if os(watchOS)
import SwiftUI

/// watchOS SwiftUI view that displays the current reply from the iPhone.
///
/// - Receives reply state from ``WatchSessionManager``
/// - Shows current reply text large and centered
/// - Index indicator "1 / 3" at bottom
/// - Dark grey background normally, blue when singleTap received
/// - Brief green flash when doubleTap received (sent confirmation)
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

            // "Sent!" overlay
            if viewModel.showSentConfirmation {
                Text("✓ Sent")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.9))
                    .cornerRadius(10)
            }
        }
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
    @Published public var isSelected: Bool = false

    /// The current reply text to display.
    public var currentReply: String {
        guard !replies.isEmpty, selectedIndex < replies.count else { return "" }
        return replies[selectedIndex]
    }

    /// Background color based on state.
    public var backgroundColor: Color {
        if showSentConfirmation { return .green.opacity(0.3) }
        if isSelected { return .blue.opacity(0.4) }
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

    private func handleGestureAck(_ gesture: String) {
        switch gesture {
        case "singleTap":
            isSelected = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isSelected = false
            }
        case "doubleTap":
            showSentConfirmation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.showSentConfirmation = false
            }
        default:
            break
        }
    }
}
#endif
