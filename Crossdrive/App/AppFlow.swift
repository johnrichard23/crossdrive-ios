/// Which top-level part of the app is on screen.
enum AppFlow: Equatable, Sendable {
    /// Working out where to go. Shows the splash.
    case launching
    case onboarding
    case auth
    case main
}
