@testable import Crossdrive
import DataLayer
import XCTest

final class DependencyContainerTests: XCTestCase {
    private let credentials = Credentials(email: "dana@example.com", password: "secret")

    // MARK: - Which session

    func testInit_WhenThereAreNoAccounts_ShouldUseNoAuthSession() {
        // Act
        let container = DependencyContainer(
            features: AppFeatures(authentication: .none),
            environment: .preview
        )

        // Assert
        XCTAssertTrue(container.session is NoAuthSession)
    }

    func testInit_WhenAccountsAreOptional_ShouldUseTokenAuthSession() {
        // Act
        let container = DependencyContainer(
            features: AppFeatures(authentication: .optional),
            environment: .preview
        )

        // Assert
        XCTAssertTrue(container.session is TokenAuthSession)
    }

    func testInit_WhenAccountsAreRequired_ShouldUseTokenAuthSession() {
        // Act
        let container = DependencyContainer(
            features: AppFeatures(authentication: .required),
            environment: .preview
        )

        // Assert
        XCTAssertTrue(container.session is TokenAuthSession)
    }

    // MARK: - Sign out

    func testSignOut_WhenSignedIn_ShouldEndTheSessionAndClearTheHTTPSession() async throws {
        // Arrange
        let cleared = Counter()
        let container = DependencyContainer.preview(
            features: AppFeatures(authentication: .optional),
            clearHTTPSession: { _ = cleared.next() }
        )
        _ = try await container.session.signIn(credentials)

        // Act
        await container.signOut()

        // Assert
        let state = await container.session.restore()
        let token = await container.session.accessToken()
        XCTAssertEqual(state, .signedOut)
        XCTAssertNil(token)
        XCTAssertEqual(cleared.next(), 2, "the HTTP session should have been cleared once")
    }

    func testSignOut_WhenSignedIn_ShouldStopPushesBeforeTheSessionEnds() async throws {
        // Arrange: record whether the token still worked when the push was unregistered.
        let secrets = InMemorySecretStore()
        let session = TokenAuthSession(
            client: StubHTTPClient { _ in
                .json(#"{"accessToken": "a1", "refreshToken": "r1", "user": {"id": "u1"}}"#)
            },
            secrets: secrets
        )
        let tokenAtUnregister = Recorder<String?>()
        let push = ProbingPushRegistrar { await tokenAtUnregister.add(session.accessToken()) }
        let container = DependencyContainer.preview(
            features: AppFeatures(authentication: .optional),
            session: session,
            services: .testing(push: push)
        )
        _ = try await session.signIn(credentials)

        // Act
        await container.signOut()

        // Assert
        XCTAssertEqual(tokenAtUnregister.values, ["a1"])
        let tokenAfter = await session.accessToken()
        XCTAssertNil(tokenAfter)
    }

    // MARK: - Token wiring

    func testBearerInterceptor_WhenSignedIn_ShouldSendTheToken() async throws {
        // Arrange
        let session = try await signedInSession()
        let seen = stubNetwork { _ in (200, Data("{}".utf8)) }
        let client = try makeClient(interceptor: DependencyContainer
            .bearerInterceptor(for: session))

        // Act
        _ = try await client.send(.get("things"))

        // Assert
        XCTAssertEqual(seen.values, ["Bearer a1"])
    }

    func testBearerInterceptor_WhenSignedOut_ShouldSendNoAuthorizationHeader() async throws {
        // Arrange
        let session = TokenAuthSession(
            client: StubHTTPClient { _ in .json("{}") },
            secrets: InMemorySecretStore()
        )
        let seen = stubNetwork { _ in (200, Data("{}".utf8)) }
        let client = try makeClient(interceptor: DependencyContainer
            .bearerInterceptor(for: session))

        // Act
        _ = try await client.send(.get("things"))

        // Assert
        XCTAssertEqual(seen.values, ["none"])
    }

    func testBearerInterceptor_WhenTheTokenHasExpired_ShouldRefreshOnceAndRetryWithTheNewToken(
    ) async throws {
        // Arrange: the server accepts only the renewed token.
        let session = try await signedInSession()
        let seen = stubNetwork { header in
            header == "Bearer a2" ? (200, Data("{}".utf8)) : (401, Data("{}".utf8))
        }
        let client = try makeClient(interceptor: DependencyContainer
            .bearerInterceptor(for: session))

        // Act
        _ = try await client.send(.get("things"))

        // Assert
        XCTAssertEqual(seen.values, ["Bearer a1", "Bearer a2"])
    }

    func testBearerInterceptor_WhenRefreshIsRejected_ShouldFailAsUnauthorizedAndSignOut(
    ) async throws {
        // Arrange
        let session = try await signedInSession(refreshStatus: 401)
        _ = stubNetwork { _ in (401, Data("{}".utf8)) }
        let client = try makeClient(interceptor: DependencyContainer
            .bearerInterceptor(for: session))

        // Act
        let error = await sendError(client)

        // Assert
        XCTAssertEqual(error as? NetworkError, .unauthorized(message: nil))
        let state = await session.restore()
        XCTAssertEqual(state, .signedOut)
    }

    // MARK: - Helpers

    /// A session signed in as `a1`; its refresh calls return `a2` (or `refreshStatus`).
    private func signedInSession(refreshStatus: Int = 200) async throws -> TokenAuthSession {
        let authClient = StubHTTPClient { endpoint in
            switch endpoint.path {
            case "auth/refresh": .json(#"{"accessToken": "a2"}"#, status: refreshStatus)
            default: .json(#"{"accessToken": "a1", "refreshToken": "r1", "user": {"id": "u1"}}"#)
            }
        }
        let session = TokenAuthSession(client: authClient, secrets: InMemorySecretStore())
        _ = try await session.signIn(credentials)
        return session
    }

    /// Answers the main client's requests; returns what `Authorization` each carried.
    private func stubNetwork(
        _ reply: @escaping @Sendable (String?) -> (Int, Data)
    ) -> Recorder<String> {
        let seen = Recorder<String>()
        StubURLProtocol.handler = { request in
            let header = request.value(forHTTPHeaderField: "Authorization")
            seen.add(header ?? "none")
            let (status, body) = reply(header)
            return (status, body)
        }
        addTeardownBlock { StubURLProtocol.handler = nil }
        return seen
    }

    private func makeClient(interceptor: BearerTokenInterceptor) throws -> URLSessionHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return try URLSessionHTTPClient(
            baseURL: XCTUnwrap(URL(string: "https://api.test.example")),
            session: URLSession(configuration: configuration),
            interceptors: [interceptor]
        )
    }

    private func sendError(_ client: URLSessionHTTPClient) async -> (any Error)? {
        do {
            _ = try await client.send(.get("things"))
            return nil
        } catch {
            return error
        }
    }
}
