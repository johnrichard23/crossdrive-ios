import DataLayer
import Foundation

/// Sign-in with an access token and a refresh token from a REST API.
///
/// The server contract this expects (change the paths and field names here if
/// the project's backend differs):
///
/// - `POST auth/sign-in` `{email, password}` → `{accessToken, refreshToken, expiresIn?, user: {id,
/// name?}}`;
///   401 for a wrong email or password
/// - `POST auth/refresh` `{refreshToken}` → `{accessToken, refreshToken?, expiresIn?}`;
///   401, 403 or 400 when the refresh token is no longer valid
/// - `POST auth/sign-out` with the bearer token → any 2xx
///
/// Tokens and the user live together in one Keychain item, so they can't
/// disagree. The `client` must NOT add the bearer token itself: it is the
/// client for these three calls, and the app's main client calls back into
/// this session for the token.
actor TokenAuthSession: AuthSession {
    nonisolated let stateUpdates: AsyncStream<SessionState>

    /// The Keychain item holding the tokens and the user.
    static let secretKey = "session"
    /// Renew this long before the access token expires.
    private static let refreshWindow: TimeInterval = 5 * 60

    private let continuation: AsyncStream<SessionState>.Continuation
    private let client: any HTTPClient
    private let secrets: any SecretStore
    private let now: @Sendable () -> Date
    private var stored: StoredSession?
    private var isLoaded = false
    private var refreshTask: Task<Bool, Never>?

    init(
        client: any HTTPClient,
        secrets: any SecretStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.secrets = secrets
        self.now = now
        (stateUpdates, continuation) = AsyncStream<SessionState>.makeStream()
    }

    // MARK: - AuthSession

    func restore() async -> SessionState {
        guard let session = await load() else { return .signedOut }
        return .signedIn(session.user)
    }

    func accessToken() async -> String? {
        await load()?.accessToken
    }

    func refreshTokens() async -> Bool {
        // Several requests can get a 401 together; they share one refresh.
        if let refreshTask {
            return await refreshTask.value
        }
        let task = Task { await performRefresh() }
        refreshTask = task
        let renewed = await task.value
        refreshTask = nil
        return renewed
    }

    func refreshIfNeeded() async {
        guard let expiresAt = await load()?.expiresAt,
              expiresAt.timeIntervalSince(now()) < Self.refreshWindow
        else { return }
        _ = await refreshTokens()
    }

    func signIn(_ credentials: Credentials) async throws -> AppUser {
        let reply: TokensReply
        do {
            reply = try await client.send(
                .post("auth/sign-in", body: SignInBody(
                    email: credentials.email,
                    password: credentials.password
                ))
            )
        } catch NetworkError.unauthorized {
            throw AuthError.invalidCredentials
        }

        guard let accessToken = reply.accessToken, !accessToken.isEmpty,
              let refreshToken = reply.refreshToken, !refreshToken.isEmpty,
              let id = reply.user?.id, !id.isEmpty
        else { throw NetworkError.invalidResponse }

        let user = AppUser(id: id, name: reply.user?.name)
        try await save(StoredSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiry(from: reply.expiresIn),
            user: user
        ))
        continuation.yield(.signedIn(user))
        return user
    }

    func signOut() async {
        // Tell the server while the token still works. Best effort, and short:
        // being offline must not keep someone signed in.
        if let token = await load()?.accessToken {
            _ = try? await client.send(Endpoint(
                path: "auth/sign-out",
                method: .post,
                headers: ["Authorization": "Bearer \(token)"],
                timeout: 5
            ))
        }
        await endSession()
    }

    // MARK: - Storage

    private func load() async -> StoredSession? {
        if isLoaded {
            return stored
        }
        do {
            if let data = try await secrets.secret(for: Self.secretKey) {
                stored = try JSONDecoder().decode(StoredSession.self, from: data)
            }
        } catch {
            // An unreadable session is treated as no session.
            AppLog.session
                .error(
                    """
                    Couldn't read the stored session: \(AppLog.summary(error), privacy: .public) \
                    \(String(describing: error), privacy: .private)
                    """
                )
        }
        isLoaded = true
        return stored
    }

    private func save(_ session: StoredSession) async throws {
        try await secrets.setSecret(JSONEncoder().encode(session), for: Self.secretKey)
        stored = session
        isLoaded = true
    }

    private func endSession() async {
        stored = nil
        isLoaded = true
        do {
            try await secrets.setSecret(nil, for: Self.secretKey)
        } catch {
            AppLog.session
                .fault(
                    """
                    Couldn't remove the stored session: \(AppLog.summary(error), privacy: .public) \
                    \(String(describing: error), privacy: .private)
                    """
                )
        }
        continuation.yield(.signedOut)
    }

    // MARK: - Refresh

    private func performRefresh() async -> Bool {
        guard let current = await load() else { return false }
        do {
            let reply: TokensReply = try await client.send(
                .post("auth/refresh", body: RefreshBody(refreshToken: current.refreshToken))
            )
            guard let accessToken = reply.accessToken, !accessToken.isEmpty else { return false }

            // Signed out, or signed in again as someone else, while we waited:
            // this reply must not bring the old session back.
            guard stored?.refreshToken == current.refreshToken else { return false }

            try await save(StoredSession(
                accessToken: accessToken,
                refreshToken: reply.refreshToken ?? current.refreshToken,
                expiresAt: expiry(from: reply.expiresIn) ?? current.expiresAt,
                user: current.user
            ))
            return true
        } catch let error as NetworkError where Self.isRejection(error) {
            if stored?.refreshToken == current.refreshToken {
                await endSession()
            }
            return false
        } catch {
            // Offline, a server error, a full Keychain: keep the session and
            // let the next request try again.
            AppLog.session
                .error("""
                Token refresh failed: \(AppLog.summary(error), privacy: .public) \
                \(String(describing: error), privacy: .private)
                """)
            return false
        }
    }

    private static func isRejection(_ error: NetworkError) -> Bool {
        switch error {
        case .unauthorized, .forbidden: true
        case let .client(status, _): status == 400
        default: false
        }
    }

    private func expiry(from seconds: Double?) -> Date? {
        seconds.map { now().addingTimeInterval($0) }
    }
}

// MARK: - Wire types

private struct StoredSession: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date?
    var user: AppUser
}

private struct SignInBody: Encodable {
    let email: String
    let password: String
}

private struct RefreshBody: Encodable {
    let refreshToken: String
}

private struct TokensReply: Decodable {
    var accessToken: String?
    var refreshToken: String?
    var expiresIn: Double?
    var user: UserReply?
}

private struct UserReply: Decodable {
    var id: String?
    var name: String?
}
