import Foundation
#if os(iOS)
import UIKit
#endif

/// Manages replies received via the `taptap://replies` URL scheme.
///
/// The URL format is:
/// ```
/// taptap://replies?r1=First+Reply&r2=Second+Reply&r3=Third+Reply
/// ```
///
/// Usage in a SwiftUI app entry point:
/// ```swift
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .onOpenURL { url in
///                     ReplyManager.shared.handleURL(url)
///                 }
///         }
///     }
/// }
/// ```
public final class ReplyManager {

    /// Shared singleton instance.
    public static let shared = ReplyManager()

    /// The replies parsed from the most recent `taptap://replies` URL.
    /// Contains the values of `r1`, `r2`, `r3` query parameters (in order),
    /// skipping any that are absent.
    public private(set) var replies: [String] = []

    /// The index of the currently selected reply.
    public private(set) var selectedIndex: Int = 0

    /// Set the selected index directly (clamped to valid range).
    ///
    /// Use this for tap-to-select on iPhone. For sequential navigation,
    /// prefer ``selectNext()`` and ``selectPrevious()``.
    public func setSelectedIndex(_ index: Int) {
        guard !replies.isEmpty else { return }
        selectedIndex = max(0, min(index, replies.count - 1))
    }

    /// The currently selected reply string, or `nil` if replies is empty.
    public var selectedReply: String? {
        guard !replies.isEmpty else { return nil }
        return replies[selectedIndex]
    }

    private init() {}

    /// Handle an incoming URL. If the URL matches the `taptap://replies`
    /// scheme and host, parses `r1`, `r2`, `r3` query parameters and stores
    /// their values in ``replies``.
    ///
    /// - Parameter url: The incoming URL to handle.
    /// - Returns: `true` if the URL was handled, `false` otherwise.
    @discardableResult
    public func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "taptap",
              url.host == "replies" else {
            return false
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        let queryItems = components.queryItems ?? []
        var parsed: [String] = []

        for key in ["r1", "r2", "r3"] {
            if let value = queryItems.first(where: { $0.name == key })?.value,
               !value.isEmpty {
                parsed.append(value)
            }
        }

        replies = parsed
        return true
    }

    /// Reset replies to an empty array and reset the selected index.
    public func reset() {
        replies = []
        selectedIndex = 0
    }

    /// Move the selection to the next reply (clamped to the last index).
    public func selectNext() {
        guard !replies.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, replies.count - 1)
    }

    /// Move the selection to the previous reply (clamped to 0).
    public func selectPrevious() {
        guard !replies.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }

    /// Open the Shortcuts app to send the currently selected reply.
    ///
    /// Builds and opens `shortcuts://run-shortcut?name=TapTapSend&input=[encoded reply]`.
    /// No-op if replies is empty.
    public func sendSelected() {
        #if os(iOS)
        guard let reply = selectedReply,
              let encoded = reply.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "shortcuts://run-shortcut?name=TapTapSend&input=\(encoded)") else {
            return
        }
        UIApplication.shared.open(url)
        #endif
    }
}
