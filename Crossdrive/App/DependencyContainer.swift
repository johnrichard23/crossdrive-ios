import DataLayer
import Foundation

/// Builds the app's services once and hands them out. Nothing else creates
/// the HTTP client, the secret store or the session.
///
/// Everything here is a `let`, so the container never changes after launch and
/// needs no observation. Add one property per API or repository.
final class DependencyContainer: Sendable {
    let features: AppFeatures
    let environment: AppEnvironment
    let onboarding: OnboardingStore
    let secrets: any SecretStore
    let session: any AuthSession
    let client: any HTTPClient
    let sampleAPI: SampleAPI
    let services: PlatformServices

    private let clearHTTPSession: @Sendable () async -> Void

    /// The pieces, given explicitly. Previews and tests use this through
    /// `preview(...)`; the app uses the convenience initialiser.
    init(
        features: AppFeatures,
        environment: AppEnvironment,
        onboarding: OnboardingStore,
        secrets: any SecretStore,
        session: any AuthSession,
        client: any HTTPClient,
        services: PlatformServices,
        clearHTTPSession: @escaping @Sendable () async -> Void = {}
    ) {
        self.features = features
        self.environment = environment
        self.onboarding = onboarding
        self.secrets = secrets
        self.session = session
        self.client = client
        self.services = services
        self.clearHTTPSession = clearHTTPSession
        sampleAPI = SampleAPI(client: client)
    }

    /// The real graph for the running app.
    convenience init(features: AppFeatures, environment: AppEnvironment) {
        let urlSession = Self.makeURLSession()
        func makeClient(_ interceptors: [any RequestInterceptor] = []) -> URLSessionHTTPClient {
            URLSessionHTTPClient(
                baseURL: environment.apiBaseURL,
                session: urlSession,
                defaultHeaders: ["Accept": "application/json"],
                interceptors: interceptors,
                retry: .exponential(),
                // Plain HTTP only for a local server, and only in Debug.
                security: environment.kind == .debug ? .allowingLocalhost : .standard,
                // Repositories do the caching, not URLSession.
                cachePolicy: .reloadIgnoringLocalCacheData
            )
        }

        let secrets = KeychainSecretStore(service: Bundle.main.bundleIdentifier ?? "app")
        // The session's own client has no token interceptor: it makes the
        // sign-in and refresh calls that the token comes from.
        let session = Self.makeSession(features: features, client: makeClient(), secrets: secrets)
        let client = makeClient(
            features.authentication == .none ? [] : [Self.bearerInterceptor(for: session)]
        )
        self.init(
            features: features,
            environment: environment,
            onboarding: OnboardingStore(),
            secrets: secrets,
            session: session,
            client: client,
            services: .system,
            clearHTTPSession: { await client.clearSession() }
        )
    }

    /// A graph with no network and no Keychain, for previews and tests. By
    /// default the client answers with `SampleStub`'s canned replies, and the
    /// session is a real `TokenAuthSession` over them, so sign-in works.
    static func preview(
        features: AppFeatures = .current,
        environment: AppEnvironment = .preview,
        session: (any AuthSession)? = nil,
        onboarding: OnboardingStore = OnboardingStore(),
        client: any HTTPClient = StubHTTPClient(SampleStub.handle),
        services: PlatformServices = .preview,
        clearHTTPSession: @escaping @Sendable () async -> Void = {}
    ) -> DependencyContainer {
        let secrets = InMemorySecretStore()
        return DependencyContainer(
            features: features,
            environment: environment,
            onboarding: onboarding,
            secrets: secrets,
            session: session ?? makeSession(features: features, client: client, secrets: secrets),
            client: client,
            services: services,
            clearHTTPSession: clearHTTPSession
        )
    }

    /// The one `URLSession` behind the app's clients. Nothing is cached on
    /// disk (a repository decides what to keep, and where) and no cookies are
    /// stored or sent (the session uses bearer tokens). A backend that signs
    /// in with a cookie needs cookies back on here.
    static func makeURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        return URLSession(configuration: configuration)
    }

    /// Adds the session's token to every request and, after a 401, renews it
    /// once and sends the request again.
    static func bearerInterceptor(for session: any AuthSession) -> BearerTokenInterceptor {
        BearerTokenInterceptor(
            token: { await session.accessToken() },
            refresh: { await session.refreshTokens() }
        )
    }

    private static func makeSession(
        features: AppFeatures,
        client: any HTTPClient,
        secrets: any SecretStore
    ) -> any AuthSession {
        switch features.authentication {
        case .none: NoAuthSession()
        case .optional, .required: TokenAuthSession(client: client, secrets: secrets)
        }
    }

    /// The one sign-out routine. In order: stop pushes to this device (it
    /// needs the session), tell the server and remove the stored tokens, then
    /// clear what URLSession holds (cookies, cached replies, credentials).
    ///
    /// As the app grows, add each repository's cache clearing here.
    func signOut() async {
        await services.push.unregister()
        await session.signOut()
        await clearHTTPSession()
    }

    /// Called when the app comes back to the foreground.
    func refreshSessionIfNeeded() async {
        await session.refreshIfNeeded()
    }
}
