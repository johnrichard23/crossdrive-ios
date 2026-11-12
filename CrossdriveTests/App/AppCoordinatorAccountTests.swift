@testable import Crossdrive
import XCTest

/// Sign-in, sign-out and the login gate. Launch routing is in `AppCoordinatorTests`.
@MainActor
final class AppCoordinatorAccountTests: XCTestCase {
    private let suiteName = "AppCoordinatorAccountTests"
    private let dana = AppUser(id: "u1", name: "Dana")
    private let credentials = Credentials(email: "dana@example.com", password: "secret")

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Login gate

    func testRequireAccount_WhenGuestInAnOptionalApp_ShouldOpenTheGateAndHoldTheAction() async {
        // Arrange
        let coordinator = await startedCoordinator(AppFeatures(authentication: .optional))
        let ran = Counter()

        // Act
        coordinator.requireAccount { _ = ran.next() }

        // Assert
        XCTAssertNotNil(coordinator.loginGate)
        XCTAssertEqual(ran.next(), 1, "the action should not have run yet")
    }

    func testRequireAccount_WhenTheGuestSignsIn_ShouldRunTheActionOnceAndCloseTheGate(
    ) async throws {
        // Arrange
        let coordinator = await startedCoordinator(AppFeatures(authentication: .optional))
        let ran = Counter()
        coordinator.requireAccount { _ = ran.next() }

        // Act
        try await coordinator.signIn(credentials)

        // Assert
        XCTAssertNil(coordinator.loginGate)
        XCTAssertEqual(ran.next(), 2, "the action should have run exactly once")
    }

    func testRequireAccount_WhenTheGateIsCancelled_ShouldDropTheAction() async throws {
        // Arrange
        let coordinator = await startedCoordinator(AppFeatures(authentication: .optional))
        let ran = Counter()
        coordinator.requireAccount { _ = ran.next() }
        coordinator.loginGate = nil
        coordinator.loginGateDidDismiss()

        // Act: signing in later does not resurrect the old action.
        try await coordinator.signIn(credentials)

        // Assert
        XCTAssertEqual(ran.next(), 1, "the action should never have run")
    }

    func testRequireAccount_WhenAlreadySignedIn_ShouldRunTheActionAtOnce() async {
        // Arrange
        let coordinator = await startedCoordinator(
            AppFeatures(authentication: .optional),
            session: FakeAuthSession(state: .signedIn(dana))
        )
        let ran = Counter()

        // Act
        coordinator.requireAccount { _ = ran.next() }

        // Assert
        XCTAssertNil(coordinator.loginGate)
        XCTAssertEqual(ran.next(), 2)
    }

    func testRequireAccount_WhenTheAppHasNoAccounts_ShouldRunTheActionAtOnce() async {
        // Arrange
        let coordinator = await startedCoordinator(AppFeatures(authentication: .none))
        let ran = Counter()

        // Act
        coordinator.requireAccount { _ = ran.next() }

        // Assert
        XCTAssertNil(coordinator.loginGate)
        XCTAssertEqual(ran.next(), 2)
    }

    // MARK: - Sign in

    func testSignIn_WhenSignInIsRequired_ShouldLeaveTheAuthFlowForMain() async throws {
        // Arrange
        let coordinator = await startedCoordinator(
            AppFeatures(authentication: .required),
            session: FakeAuthSession(signInResult: .success(dana))
        )
        XCTAssertEqual(coordinator.flow, .auth)

        // Act
        try await coordinator.signIn(credentials)

        // Assert
        XCTAssertEqual(coordinator.flow, .main)
        XCTAssertEqual(coordinator.session, .signedIn(dana))
    }

    func testSignIn_WhenSignInIsRequiredAndOnboardingFollowsIt_ShouldShowOnboarding() async throws {
        // Arrange
        let features = AppFeatures(
            authentication: .required,
            onboarding: true,
            onboardingPlacement: .afterSignIn
        )
        let coordinator = await startedCoordinator(features)

        // Act
        try await coordinator.signIn(credentials)

        // Assert
        XCTAssertEqual(coordinator.flow, .onboarding)
    }

    func testSignIn_WhenTheServerRejectsIt_ShouldThrowAndStaySignedOut() async {
        // Arrange
        let session = FakeAuthSession(signInResult: .failure(AuthError.invalidCredentials))
        let coordinator = await startedCoordinator(
            AppFeatures(authentication: .optional),
            session: session
        )

        // Act and Assert
        do {
            try await coordinator.signIn(credentials)
            XCTFail("signIn should have thrown")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
        XCTAssertEqual(coordinator.session, .signedOut)
    }

    // MARK: - Sign out

    func testSignOut_WhenAccountsAreOptional_ShouldStayOnMainAsGuestWithFreshTabs() async {
        // Arrange
        let session = FakeAuthSession(state: .signedIn(dana))
        let coordinator = await startedCoordinator(
            AppFeatures(authentication: .optional),
            session: session
        )
        let tokenBefore = coordinator.mainResetToken

        // Act
        await coordinator.signOut()

        // Assert
        XCTAssertEqual(coordinator.flow, .main)
        XCTAssertEqual(coordinator.session, .signedOut)
        XCTAssertNotEqual(coordinator.mainResetToken, tokenBefore)
        let calls = await session.signOutCalls
        XCTAssertEqual(calls, 1)
    }

    func testSignOut_WhenSignInIsRequired_ShouldReturnToTheAuthFlow() async {
        // Arrange
        let coordinator = await startedCoordinator(
            AppFeatures(authentication: .required),
            session: FakeAuthSession(state: .signedIn(dana))
        )
        XCTAssertEqual(coordinator.flow, .main)

        // Act
        await coordinator.signOut()

        // Assert
        XCTAssertEqual(coordinator.flow, .auth)
    }

    func testSession_WhenItEndsByItself_ShouldReturnToTheAuthFlow() async {
        // Arrange: for example, the server rejected the refresh token.
        let session = FakeAuthSession(state: .signedIn(dana))
        let coordinator = await startedCoordinator(
            AppFeatures(authentication: .required),
            session: session
        )
        XCTAssertEqual(coordinator.flow, .main)

        // Act
        await session.send(.signedOut)
        await waitUntil { coordinator.flow == .auth }

        // Assert
        XCTAssertEqual(coordinator.flow, .auth)
        XCTAssertEqual(coordinator.session, .signedOut)
    }

    // MARK: - Helpers

    private func startedCoordinator(
        _ features: AppFeatures,
        session: (any AuthSession)? = nil
    ) async -> AppCoordinator {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let container = DependencyContainer.preview(
            features: features,
            session: session ?? FakeAuthSession(),
            onboarding: OnboardingStore(defaults: defaults)
        )
        let coordinator = AppCoordinator(container: container)
        await coordinator.start()
        return coordinator
    }

    /// Lets other main-actor work run until `condition` holds. No sleeping.
    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0 ..< 1000 {
            if condition() {
                return
            }
            await Task.yield()
        }
    }
}
