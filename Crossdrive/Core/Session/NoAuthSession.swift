/// For an app without accounts (`AppFeatures.Authentication.none`): nobody is
/// ever signed in, and nobody can be.
struct NoAuthSession: AuthSession {
    var stateUpdates: AsyncStream<SessionState> {
        AsyncStream { $0.finish() }
    }

    func restore() async -> SessionState {
        .signedOut
    }

    func accessToken() async -> String? {
        nil
    }

    func refreshTokens() async -> Bool {
        false
    }

    func signIn(_: Credentials) async throws -> AppUser {
        throw AuthError.notSupported
    }

    func signOut() async {}
}
