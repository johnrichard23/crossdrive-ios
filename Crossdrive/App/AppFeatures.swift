import Foundation

/// The shape of this app: whether it has accounts and whether it has
/// onboarding. This is the only place a project states it; the launch path
/// follows from these values.
struct AppFeatures: Sendable, Equatable {
    /// How accounts work in this app.
    enum Authentication: Sendable, CaseIterable {
        /// No accounts at all.
        case none
        /// Usable as a guest; signing in unlocks more.
        case optional
        /// Nothing is usable until the user signs in.
        case required
    }

    /// When onboarding runs in an app that requires sign-in.
    enum OnboardingPlacement: Sendable, CaseIterable {
        case beforeSignIn
        case afterSignIn
    }

    var authentication: Authentication = .optional
    var onboarding: Bool = false
    var onboardingPlacement: OnboardingPlacement = .afterSignIn

    /// This app's settings. Change the values here for a new project.
    ///
    /// A Debug build can override them with launch arguments, to try the other
    /// launch paths without editing code (see `AppFeatures+DebugOverrides`).
    static let current: AppFeatures = {
        var features = AppFeatures(
            authentication: .optional,
            onboarding: true,
            onboardingPlacement: .afterSignIn
        )
        #if DEBUG
            features.applyOverrides(UserDefaults.standard)
        #endif
        return features
    }()
}
