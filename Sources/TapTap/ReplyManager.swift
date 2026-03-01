import Foundation

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

    /// Reset replies to an empty array.
    public func reset() {
        replies = []
    }
}
