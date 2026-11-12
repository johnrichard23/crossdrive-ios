/// Why signing in failed, when the cause is the user's input or the app's
/// setup. Network problems arrive as `NetworkError`.
enum AuthError: Error, Equatable, Sendable {
    /// The server rejected the email or password.
    case invalidCredentials
    /// This app has no accounts (`AppFeatures.Authentication.none`).
    case notSupported
}
