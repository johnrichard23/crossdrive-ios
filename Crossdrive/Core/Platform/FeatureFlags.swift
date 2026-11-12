import Foundation

/// A switch for one feature. Define each as a `static let` below, with the
/// value it has when nothing says otherwise.
struct FeatureFlag: Hashable, Sendable {
    let key: String
    let defaultValue: Bool
}

extension FeatureFlag {
    /// The sample's favourite button and swipe action.
    static let favorites = FeatureFlag(key: "favorites", defaultValue: true)

    /// Every flag, for the debug menu.
    static let all: [FeatureFlag] = [.favorites]
}

protocol FeatureFlags: Sendable {
    func isEnabled(_ flag: FeatureFlag) -> Bool
}

/// Flags from the code's defaults. In Debug and Staging builds the debug menu
/// can override one (stored in `UserDefaults`); a Release build never reads
/// an override.
///
/// A remote-config vendor replaces this with its own `FeatureFlags`.
struct LocalFeatureFlags: FeatureFlags {
    private let defaults: UserDefaults?

    /// `nil` ignores overrides entirely (previews).
    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        #if DEBUG || STAGING
            if let override = defaults?.object(forKey: Self.overrideKey(flag)) as? Bool {
                return override
            }
        #endif
        return flag.defaultValue
    }

    #if DEBUG || STAGING
        func setOverride(_ value: Bool?, for flag: FeatureFlag) {
            if let value {
                defaults?.set(value, forKey: Self.overrideKey(flag))
            } else {
                defaults?.removeObject(forKey: Self.overrideKey(flag))
            }
        }
    #endif

    private static func overrideKey(_ flag: FeatureFlag) -> String {
        "flag.\(flag.key)"
    }
}

/// UserDefaults is documented as thread-safe.
extension LocalFeatureFlags: @unchecked Sendable {}
