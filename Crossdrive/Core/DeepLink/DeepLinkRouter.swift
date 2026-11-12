import Foundation

/// Turns a URL into a `DeepLink`, or into nothing. Anything it doesn't
/// recognise is ignored, never half-handled.
///
/// Understood:
/// - `<scheme>://items/<id>` (the app's own scheme, from `Info.plist`)
/// - `https://<host>/items/<id>` for each host in `universalLinkHosts`
///   (empty until a project sets up associated domains)
///
/// Everything after the path (a query, a fragment) is ignored, and an id is
/// checked before it can reach a screen or an API path.
struct DeepLinkRouter: Sendable {
    private static let maxIDLength = 200

    let scheme: String
    let universalLinkHosts: Set<String>

    init(scheme: String, universalLinkHosts: Set<String> = []) {
        self.scheme = scheme.lowercased()
        self.universalLinkHosts = Set(universalLinkHosts.map { $0.lowercased() })
    }

    /// The scheme the app registered: the first one under `CFBundleURLTypes`.
    /// That is the one place it is written (`Config/*.xcconfig`).
    init(bundle: Bundle = .main) {
        let types = bundle.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]]
        let schemes = types?.first?["CFBundleURLSchemes"] as? [String]
        self.init(scheme: schemes?.first ?? "")
    }

    func parse(_ url: URL) -> DeepLink? {
        let path = url.pathComponents.filter { $0 != "/" }
        let segments: [String]

        switch url.scheme?.lowercased() {
        case scheme where !scheme.isEmpty:
            segments = (url.host(percentEncoded: false).map { [$0] } ?? []) + path
        case "https":
            guard let host = url.host(percentEncoded: false)?.lowercased(),
                  universalLinkHosts.contains(host)
            else { return nil }
            segments = path
        default:
            return nil
        }

        guard segments.count == 2, segments[0] == "items", Self.isValid(id: segments[1]) else {
            return nil
        }
        return .item(segments[1])
    }

    /// For text from a push notification's payload.
    func parse(_ text: String) -> DeepLink? {
        URL(string: text).flatMap(parse)
    }

    private static func isValid(id: String) -> Bool {
        !id.isEmpty
            && id.count <= maxIDLength
            && id.rangeOfCharacter(from: .controlCharacters) == nil
    }
}
