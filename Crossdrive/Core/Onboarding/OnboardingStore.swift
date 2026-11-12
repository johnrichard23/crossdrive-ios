import CryptoKit
import Foundation

/// Remembers, on this device, that onboarding has been finished.
///
/// - Seen while signed out (an app without accounts, a guest, or onboarding
///   placed before sign-in): remembered for the whole device.
/// - Seen while signed in: remembered for that account only, so the next
///   person to sign in on this phone sees it too.
///
/// Onboarding counts as done if either applies. The account marker survives
/// sign-out on purpose (otherwise it would repeat at every sign-in), so it is
/// keyed by a one-way hash of the user id, never the id itself.
///
/// shortcut: local only, so a new device repeats onboarding; add a server flag
/// when a project needs it to follow the account.
struct OnboardingStore: @unchecked Sendable { // UserDefaults is documented thread-safe
    private static let deviceKey = "onboarding.completed"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isDone(for session: SessionState) -> Bool {
        if defaults.bool(forKey: Self.deviceKey) {
            return true
        }
        guard case let .signedIn(user) = session else { return false }
        return defaults.bool(forKey: Self.accountKey(for: user))
    }

    func markDone(for session: SessionState) {
        switch session {
        case .signedOut: defaults.set(true, forKey: Self.deviceKey)
        case let .signedIn(user): defaults.set(true, forKey: Self.accountKey(for: user))
        }
    }

    private static func accountKey(for user: AppUser) -> String {
        let digest = SHA256.hash(data: Data(user.id.utf8))
        return "\(deviceKey).account.\(digest.map { String(format: "%02x", $0) }.joined())"
    }
}
