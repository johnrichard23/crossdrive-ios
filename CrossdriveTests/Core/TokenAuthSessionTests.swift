@testable import Crossdrive
import DataLayer
import XCTest

private let signInReply = #"""
{"accessToken": "a1", "refreshToken": "r1", "expiresIn": 3600, "user": {"id": "u1", "name": "Dana"}}
"""#
private let credentials = Credentials(email: "dana@example.com", password: "secret")
private let dana = AppUser(id: "u1", name: "Dana")

final class TokenAuthSessionTests: XCTestCase {
    private let secrets = InMemorySecretStore()

    // MARK: - Restore

    func testRestore_WhenNothingIsStored_ShouldBeSignedOut() async {
        // Arrange
        let (session, _) = makeSession { _ in .json("{}") }

        // Act
        let state = await session.restore()

        // Assert
        XCTAssertEqual(state, .signedOut)
    }

    func testRestore_WhenTheStoredSessionIsCorrupt_ShouldBeSignedOut() async {
        // Arrange
        await secrets.setSecret(Data("not json".utf8), for: TokenAuthSession.secretKey)
        let (session, _) = makeSession { _ in .json("{}") }

        // Act
        let state = await session.restore()

        // Assert
        XCTAssertEqual(state, .signedOut)
    }

    // MARK: - Sign in

    func testSignIn_WhenServerAccepts_ShouldReturnTheUserAndSurviveARelaunch() async throws {
        // Arrange
        let (session, _) = makeSession { _ in .json(signInReply) }

        // Act
        let user = try await session.signIn(credentials)

        // Assert
        XCTAssertEqual(user, dana)
        let (relaunched, _) = makeSession { _ in .json("{}") }
        let restored = await relaunched.restore()
        let token = await relaunched.accessToken()
        XCTAssertEqual(restored, .signedIn(dana))
        XCTAssertEqual(token, "a1")
    }

    func testSignIn_WhenCalled_ShouldPostTheCredentialsToTheSignInPath() async throws {
        // Arrange
        let (session, client) = makeSession { _ in .json(signInReply) }

        // Act
        _ = try await session.signIn(credentials)

        // Assert
        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.path, "auth/sign-in")
        XCTAssertEqual(request.method, .post)
        let body = try JSONDecoder().decode([String: String].self, from: XCTUnwrap(request.body))
        XCTAssertEqual(body, ["email": "dana@example.com", "password": "secret"])
    }

    func testSignIn_WhenServerRejectsThePassword_ShouldThrowInvalidCredentialsAndStoreNothing(
    ) async {
        // Arrange
        let (session, _) = makeSession { _ in .json("{}", status: 401) }

        // Act
        let error = await signInError(session)

        // Assert
        XCTAssertEqual(error as? AuthError, .invalidCredentials)
        let token = await session.accessToken()
        XCTAssertNil(token)
    }

    func testSignIn_WhenServerIsDown_ShouldPassTheNetworkErrorThrough() async {
        // Arrange
        let (session, _) = makeSession { _ in .json("{}", status: 503) }

        // Act
        let error = await signInError(session)

        // Assert
        XCTAssertEqual(error as? NetworkError, .server(status: 503, message: nil))
    }

    func testSignIn_WhenTheReplyHasNoTokens_ShouldThrowInvalidResponseAndStoreNothing() async {
        // Arrange
        let (session, _) = makeSession { _ in .json(#"{"user": {"id": "u1"}}"#) }

        // Act
        let error = await signInError(session)

        // Assert
        XCTAssertEqual(error as? NetworkError, .invalidResponse)
        let state = await session.restore()
        XCTAssertEqual(state, .signedOut)
    }

    // MARK: - Refresh

    func testRefreshTokens_WhenServerAccepts_ShouldReplaceTheTokens() async throws {
        // Arrange
        let (session, client) = makeSession { endpoint in
            endpoint.path == "auth/refresh"
                ? .json(#"{"accessToken": "a2", "refreshToken": "r2"}"#)
                : .json(signInReply)
        }
        _ = try await session.signIn(credentials)

        // Act
        let renewed = await session.refreshTokens()

        // Assert
        XCTAssertTrue(renewed)
        let token = await session.accessToken()
        XCTAssertEqual(token, "a2")
        let sent = try JSONDecoder().decode(
            [String: String].self,
            from: XCTUnwrap(client.requests.last?.body)
        )
        XCTAssertEqual(sent, ["refreshToken": "r1"])
    }

    func testRefreshTokens_WhenTheReplyOmitsTheRefreshToken_ShouldKeepTheOldOne() async throws {
        // Arrange
        let (session, client) = makeSession { endpoint in
            endpoint.path == "auth/refresh" ? .json(#"{"accessToken": "a2"}"#) : .json(signInReply)
        }
        _ = try await session.signIn(credentials)
        _ = await session.refreshTokens()

        // Act
        _ = await session.refreshTokens()

        // Assert
        let sent = try JSONDecoder().decode(
            [String: String].self,
            from: XCTUnwrap(client.requests.last?.body)
        )
        XCTAssertEqual(sent, ["refreshToken": "r1"])
    }

    func testRefreshTokens_WhenServerRejectsTheRefreshToken_ShouldSignOut() async throws {
        // Arrange
        let (session, _) = makeSession { endpoint in
            endpoint.path == "auth/refresh" ? .json("{}", status: 401) : .json(signInReply)
        }
        _ = try await session.signIn(credentials)

        // Act
        let renewed = await session.refreshTokens()

        // Assert
        XCTAssertFalse(renewed)
        let state = await session.restore()
        XCTAssertEqual(state, .signedOut)
        var updates = session.stateUpdates.makeAsyncIterator()
        let first = await updates.next()
        let second = await updates.next()
        XCTAssertEqual(first, .signedIn(dana))
        XCTAssertEqual(second, .signedOut)
    }

    func testRefreshTokens_WhenOffline_ShouldKeepTheSession() async throws {
        // Arrange
        let (session, _) = makeSession { endpoint in
            if endpoint.path == "auth/refresh" {
                throw NetworkError.noConnection
            }
            return .json(signInReply)
        }
        _ = try await session.signIn(credentials)

        // Act
        let renewed = await session.refreshTokens()

        // Assert
        XCTAssertFalse(renewed)
        let state = await session.restore()
        XCTAssertEqual(state, .signedIn(dana))
    }

    func testRefreshTokens_WhenCalledWhileARefreshIsRunning_ShouldShareIt() async throws {
        // Arrange: the refresh request waits for the server.
        let started = Gate()
        let release = Gate()
        let (session, client) = makeSession { endpoint in
            guard endpoint.path == "auth/refresh" else { return .json(signInReply) }
            await started.open()
            await release.wait()
            return .json(#"{"accessToken": "a2"}"#)
        }
        _ = try await session.signIn(credentials)
        let first = Task { await session.refreshTokens() }
        await started.wait()
        let second = Task { await session.refreshTokens() }
        for _ in 0 ..< 100 {
            await Task.yield()
        }

        // Act
        await release.open()
        let results = await [first.value, second.value]

        // Assert
        XCTAssertEqual(results, [true, true])
        XCTAssertEqual(client.requests.filter { $0.path == "auth/refresh" }.count, 1)
    }

    func testRefreshTokens_WhenSignedOutWhileRefreshing_ShouldNotBringTheSessionBack() async throws {
        // Arrange
        let started = Gate()
        let release = Gate()
        let (session, _) = makeSession { endpoint in
            guard endpoint.path == "auth/refresh" else { return .json(signInReply) }
            await started.open()
            await release.wait()
            return .json(#"{"accessToken": "a2"}"#)
        }
        _ = try await session.signIn(credentials)
        let refresh = Task { await session.refreshTokens() }
        await started.wait()
        await session.signOut()

        // Act
        await release.open()
        let renewed = await refresh.value

        // Assert
        XCTAssertFalse(renewed)
        let state = await session.restore()
        XCTAssertEqual(state, .signedOut)
    }

    // MARK: - Refresh when about to expire

    func testRefreshIfNeeded_WhenTheTokenExpiresSoon_ShouldRefresh() async throws {
        // Arrange
        let clock = TestClock()
        let (session, client) = makeSession(clock: clock) { endpoint in
            endpoint.path == "auth/refresh" ? .json(#"{"accessToken": "a2"}"#) : .json(signInReply)
        }
        _ = try await session.signIn(credentials)
        clock.advance(by: 3600 - 60)

        // Act
        await session.refreshIfNeeded()

        // Assert
        XCTAssertEqual(client.requests.filter { $0.path == "auth/refresh" }.count, 1)
    }

    func testRefreshIfNeeded_WhenTheTokenIsFarFromExpiry_ShouldDoNothing() async throws {
        // Arrange
        let clock = TestClock()
        let (session, client) = makeSession(clock: clock) { _ in .json(signInReply) }
        _ = try await session.signIn(credentials)
        clock.advance(by: 60)

        // Act
        await session.refreshIfNeeded()

        // Assert
        XCTAssertEqual(client.requests.filter { $0.path == "auth/refresh" }.count, 0)
    }

    func testRefreshIfNeeded_WhenTheExpiryIsUnknown_ShouldDoNothing() async throws {
        // Arrange: the server didn't say when the token expires.
        let clock = TestClock()
        let (session, client) = makeSession(clock: clock) { _ in
            .json(#"{"accessToken": "a1", "refreshToken": "r1", "user": {"id": "u1"}}"#)
        }
        _ = try await session.signIn(credentials)
        clock.advance(by: 100_000)

        // Act
        await session.refreshIfNeeded()

        // Assert
        XCTAssertEqual(client.requests.filter { $0.path == "auth/refresh" }.count, 0)
    }

    // MARK: - Sign out

    func testSignOut_WhenSignedIn_ShouldTellTheServerAndForgetEverything() async throws {
        // Arrange
        let (session, client) = makeSession { _ in .json(signInReply) }
        _ = try await session.signIn(credentials)

        // Act
        await session.signOut()

        // Assert
        let request = try XCTUnwrap(client.requests.last)
        XCTAssertEqual(request.path, "auth/sign-out")
        XCTAssertEqual(request.headers["Authorization"], "Bearer a1")
        let token = await session.accessToken()
        XCTAssertNil(token)
        let (relaunched, _) = makeSession { _ in .json("{}") }
        let restored = await relaunched.restore()
        XCTAssertEqual(restored, .signedOut)
    }

    func testSignOut_WhenTheServerIsUnreachable_ShouldStillSignOut() async throws {
        // Arrange
        let (session, _) = makeSession { endpoint in
            if endpoint.path == "auth/sign-out" {
                throw NetworkError.noConnection
            }
            return .json(signInReply)
        }
        _ = try await session.signIn(credentials)

        // Act
        await session.signOut()

        // Assert
        let state = await session.restore()
        XCTAssertEqual(state, .signedOut)
    }

    func testStateUpdates_WhenSigningInAndOut_ShouldYieldEachChange() async throws {
        // Arrange
        let (session, _) = makeSession { _ in .json(signInReply) }
        _ = try await session.signIn(credentials)

        // Act
        await session.signOut()

        // Assert
        var updates = session.stateUpdates.makeAsyncIterator()
        let first = await updates.next()
        let second = await updates.next()
        XCTAssertEqual(first, .signedIn(dana))
        XCTAssertEqual(second, .signedOut)
    }

    // MARK: - Helpers

    private func makeSession(
        clock: TestClock = TestClock(),
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
    ) -> (TokenAuthSession, StubHTTPClient) {
        let client = StubHTTPClient(handler)
        let session = TokenAuthSession(client: client, secrets: secrets, now: { clock.now })
        return (session, client)
    }

    private func signInError(_ session: TokenAuthSession) async -> (any Error)? {
        do {
            _ = try await session.signIn(credentials)
            return nil
        } catch {
            return error
        }
    }
}
