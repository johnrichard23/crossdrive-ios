/// How the app knows who the user is.
///
/// One implementation per way of signing in: `NoAuthSession` (no accounts),
/// `TokenAuthSession` (access and refresh tokens from a REST API), a fake for
/// previews and tests, and whatever a project adds (a hosted web sign-in, a
/// vendor SDK).
protocol AuthSession: Sendable {
    /// Every change of who is signed in, including ones the app didn't ask for
    /// (a refresh token the server rejected). One consumer: the coordinator.
    var stateUpdates: AsyncStream<SessionState> { get }

    /// The session left over from a previous launch. Must not wait on the
    /// network: offline with stored credentials counts as signed in.
    func restore() async -> SessionState

    /// The current access token, or `nil` when signed out.
    func accessToken() async -> String?

    /// Renews the access token. `true` if it was renewed. Rejected
    /// credentials end the session; being offline does not.
    func refreshTokens() async -> Bool

    /// Renews the access token if it is about to expire. Does nothing when
    /// the expiry isn't known.
    func refreshIfNeeded() async

    func signIn(_ credentials: Credentials) async throws -> AppUser

    /// Ends the session and removes everything stored for it. Never throws:
    /// being offline must not keep someone signed in.
    func signOut() async
}

extension AuthSession {
    func refreshIfNeeded() async {}
}
