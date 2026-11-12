/// Decides where the app goes once the session is known. A pure function of
/// the app's settings and the user's state, so every case is unit tested.
///
/// - `none` and `optional`: onboarding (if on and not done), then main.
/// - `required`: sign-in first, unless onboarding is set to run before it.
enum LaunchRouter {
    static func flow(
        features: AppFeatures,
        session: SessionState,
        onboardingDone: Bool
    ) -> AppFlow {
        let needsOnboarding = features.onboarding && !onboardingDone

        switch (features.authentication, session) {
        case (.none, _), (.optional, _), (.required, .signedIn):
            return needsOnboarding ? .onboarding : .main
        case (.required, .signedOut):
            if needsOnboarding, features.onboardingPlacement == .beforeSignIn {
                return .onboarding
            }
            return .auth
        }
    }
}
