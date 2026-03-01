#if os(iOS)
import SwiftUI

/// iPhone-side SwiftUI view that displays 3 reply cards.
///
/// - Observes `ReplyManager.shared` via a 0.1s timer
/// - Highlights the selected reply card in blue
/// - Shows "Sent!" briefly when `doubleTap` fires
///
/// Usage in the app entry point:
/// ```swift
/// @main
/// struct taptaptapApp: App {
///     init() {
///         _ = PhoneSessionManager.shared
///         GestureRouter.shared.onGesture = { gesture in
///             // handled automatically — see PhoneContentView
///         }
///     }
///     var body: some Scene {
///         WindowGroup {
///             PhoneContentView()
///                 .onOpenURL { url in
///                     ReplyManager.shared.handleURL(url)
///                 }
///         }
///     }
/// }
/// ```
public struct PhoneContentView: View {

    @StateObject private var viewModel = PhoneReplyViewModel()

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("TapTap Replies")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 20)

                if viewModel.replies.isEmpty {
                    Spacer()
                    Text("Waiting for replies...")
                        .foregroundColor(.gray)
                        .font(.headline)
                    Text("Open a taptap://replies URL to load replies")
                        .foregroundColor(.gray.opacity(0.7))
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                } else {
                    ForEach(Array(viewModel.replies.enumerated()), id: \.offset) { index, reply in
                        ReplyCard(
                            text: reply,
                            isSelected: index == viewModel.selectedIndex,
                            index: index
                        ) { tappedIndex in
                            viewModel.selectReply(at: tappedIndex)
                        }
                    }
                    Spacer()
                }
            }
            .padding()

            // "Sent!" overlay
            if viewModel.showSentConfirmation {
                VStack {
                    Spacer()
                    Text("Sent!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.green.opacity(0.9))
                        .cornerRadius(16)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
    }
}

/// A single reply card view.
struct ReplyCard: View {
    let text: String
    let isSelected: Bool
    let index: Int
    var onTap: ((Int) -> Void)?

    var body: some View {
        HStack {
            Text(text)
                .font(.body)
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding()
        .background(isSelected ? Color.blue : Color.gray.opacity(0.3))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onTapGesture {
            onTap?(index)
        }
    }
}

/// ViewModel that polls `ReplyManager.shared` and listens
/// to `GestureRouter` for UI-specific state (sent confirmation).
public final class PhoneReplyViewModel: ObservableObject {
    @Published public var replies: [String] = []
    @Published public var selectedIndex: Int = 0
    @Published public var showSentConfirmation: Bool = false

    private var timer: Timer?
    private var previousOnGesture: ((String) -> Void)?

    public init() {
        // Poll ReplyManager state at 10 Hz
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.syncState()
            }
        }

        // Wire up GestureRouter for UI feedback
        GestureRouter.shared.onGesture = { [weak self] gesture in
            DispatchQueue.main.async {
                self?.handleGesture(gesture)
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func syncState() {
        let mgr = ReplyManager.shared
        let repliesChanged = mgr.replies != replies
        let indexChanged = mgr.selectedIndex != selectedIndex
        if repliesChanged {
            replies = mgr.replies
        }
        if indexChanged {
            selectedIndex = mgr.selectedIndex
        }
        // Push to watch whenever state changes (e.g. after URL loading)
        if repliesChanged || indexChanged {
            PhoneSessionManager.shared.pushReplyState()
        }
    }

    private func handleGesture(_ gesture: String) {
        switch gesture {
        case "swipeUp":
            showSentConfirmation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.showSentConfirmation = false
            }
        default:
            break
        }
    }

    /// Select a reply by tapping its card on the iPhone.
    public func selectReply(at index: Int) {
        ReplyManager.shared.setSelectedIndex(index)
        // Update local state immediately for responsive UI (also picked up by syncState timer)
        selectedIndex = ReplyManager.shared.selectedIndex
        PhoneSessionManager.shared.pushReplyState()
    }
}
#endif
