import Foundation

/// Which backend the app talks to and which build flavour is running.
///
/// The values come from the active `.xcconfig` (see `Config/`), copied into
/// `Info.plist` at build time. No URL or key is written in Swift source.
struct AppEnvironment: Sendable, Equatable {
    /// The build flavour. One per build configuration.
    enum Kind: String, Sendable, CaseIterable {
        case debug
        case staging
        case release
    }

    /// Why the configuration could not be read. Always a build-setup mistake,
    /// never something the user can fix.
    enum ConfigurationError: Error, Equatable {
        /// The key is absent or empty: the `.xcconfig` doesn't define it.
        case missing(key: String)
        /// The key is present but its value can't be used.
        case invalid(key: String, value: String)
    }

    private enum Key {
        static let kind = "APP_ENVIRONMENT"
        static let apiBaseURL = "API_BASE_URL"
    }

    let kind: Kind
    let apiBaseURL: URL

    init(kind: Kind, apiBaseURL: URL) {
        self.kind = kind
        self.apiBaseURL = apiBaseURL
    }

    /// Reads and validates the configuration from an `Info.plist` dictionary.
    init(info: [String: Any]) throws(ConfigurationError) {
        let kindValue = try Self.string(Key.kind, in: info)
        guard let kind = Kind(rawValue: kindValue) else {
            throw .invalid(key: Key.kind, value: kindValue)
        }

        let urlValue = try Self.string(Key.apiBaseURL, in: info)
        guard let url = URL(string: urlValue),
              let scheme = url.scheme?.lowercased(),
              url.host()?.isEmpty == false,
              // Plain HTTP is for a local development server only.
              scheme == "https" || (scheme == "http" && kind == .debug)
        else {
            throw .invalid(key: Key.apiBaseURL, value: urlValue)
        }

        self.init(kind: kind, apiBaseURL: url)
    }

    /// A made-up environment for previews and tests. Never used to reach a server.
    static let preview = AppEnvironment(
        kind: .debug,
        apiBaseURL: URL(string: "https://preview.example.com")!
    )

    /// The configuration of the running app.
    static func load(from bundle: Bundle = .main) throws(ConfigurationError) -> AppEnvironment {
        try AppEnvironment(info: bundle.infoDictionary ?? [:])
    }

    private static func string(
        _ key: String,
        in info: [String: Any]
    ) throws(ConfigurationError) -> String {
        let value = (info[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { throw .missing(key: key) }
        return value
    }
}
