/// A session whose answers are decided by the caller, for previews and tests.
actor FakeAuthSession: AuthSession {
    nonisolated let stateUpdates: AsyncStream<SessionState>

    private let continuation: AsyncStream<SessionState>.Continuation
    private var state: SessionState
    private let signInResult: Result<AppUser, any Error>
    private(set) var signOutCalls = 0

    init(
        state: SessionState = .signedOut,
        signInResult: Result<AppUser, any Error> = .success(AppUser(id: "fake", name: "Fake User"))
    ) {
        self.state = state
        self.signInResult = signInResult
        (stateUpdates, continuation) = AsyncStream<SessionState>.makeStream()
    }

    /// Pretends the session changed by itself (for example, it expired).
    func send(_ newState: SessionState) {
        state = newState
        continuation.yield(newState)
    }

    func restore() -> SessionState {
        state
    }

    func accessToken() -> String? {
        nil
    }

    func refreshTokens() -> Bool {
        false
    }

    func signIn(_: Credentials) throws -> AppUser {
        let user = try signInResult.get()
        send(.signedIn(user))
        return user
    }

    func signOut() {
        signOutCalls += 1
        send(.signedOut)
    }
}
