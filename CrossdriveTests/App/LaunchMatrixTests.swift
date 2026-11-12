@testable import Crossdrive
import XCTest

/// The six launch paths (accounts × onboarding), each played through with
/// the real coordinator, router and stores. A "launch" is a fresh coordinator
/// on the same on-device storage, with the session left from before.
@MainActor
final class LaunchMatrixTests: XCTestCase {
    private let suiteName = "LaunchMatrixTests"
    private let dana = AppUser(id: "dana", name: "Dana")
    private let sam = AppUser(id: "sam", name: "Sam")
    private let credentials = Credentials(email: "a@example.com", password: "secret")

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Row 1: no accounts, no onboarding

    func testLaunch_WhenNoAccountsAndNoOnboarding_ShouldAlwaysShowMain() async {
        // Arrange
        let features = AppFeatures(authentication: .none, onboarding: false)

        // Act
        let first = await launch(features)
        let second = await launch(features)

        // Assert
        XCTAssertEqual(first.flow, .main)
        XCTAssertEqual(second.flow, .main)
    }

    // MARK: - Row 2: no accounts, onboarding

    func testLaunch_WhenNoAccountsAndOnboarding_ShouldShowItOnceThenMain() async {
        // Arrange
        let features = AppFeatures(authentication: .none, onboarding: true)
        let first = await launch(features)

        // Act
        let beforeFinishing = first.flow
        first.finishOnboarding()
        let second = await launch(features)

        // Assert
        XCTAssertEqual(beforeFinishing, .onboarding)
        XCTAssertEqual(first.flow, .main)
        XCTAssertEqual(second.flow, .main)
    }

    // MARK: - Row 3: optional accounts, no onboarding

    func testLaunch_WhenAccountsAreOptionalAndNoOnboarding_ShouldShowMainAsGuest() async {
        // Act
        let coordinator = await launch(AppFeatures(authentication: .optional, onboarding: false))

        // Assert
        XCTAssertEqual(coordinator.flow, .main)
        XCTAssertEqual(coordinator.session, .signedOut)
    }

    // MARK: - Row 4: optional accounts, onboarding

    func testLaunch_WhenAccountsAreOptionalAndOnboarding_ShouldOnboardAGuestThenShowMain(
    ) async throws {
        // Arrange
        let features = AppFeatures(authentication: .optional, onboarding: true)
        let first = await launch(features)

        // Act
        var flows = [first.flow]
        first.finishOnboarding()
        flows.append(first.flow)
        try await first.signIn(credentials)
        flows.append(first.flow)
        let second = await launch(features, restored: .signedIn(dana))
        flows.append(second.flow)

        // Assert: signing in later does not repeat onboarding.
        XCTAssertEqual(flows, [.onboarding, .main, .main, .main])
        XCTAssertEqual(first.session, .signedIn(dana))
    }

    // MARK: - Row 5: required accounts, no onboarding

    func testLaunch_WhenSignInIsRequiredAndNoOnboarding_ShouldSignInThenShowMain() async throws {
        // Arrange
        let features = AppFeatures(authentication: .required, onboarding: false)
        let first = await launch(features)

        // Act
        var flows = [first.flow]
        try await first.signIn(credentials)
        flows.append(first.flow)
        let restored = await launch(features, restored: .signedIn(dana))
        flows.append(restored.flow)
        let signedOut = await launch(features)
        flows.append(signedOut.flow)

        // Assert
        XCTAssertEqual(flows, [.auth, .main, .main, .auth])
    }

    // MARK: - Row 6: required accounts, onboarding

    func testLaunch_WhenSignInIsRequiredAndOnboardingFollowsIt_ShouldGoAuthThenOnboardingThenMain(
    ) async throws {
        // Arrange
        let features = AppFeatures(
            authentication: .required,
            onboarding: true,
            onboardingPlacement: .afterSignIn
        )
        let first = await launch(features)

        // Act
        var flows = [first.flow]
        try await first.signIn(credentials)
        flows.append(first.flow)
        first.finishOnboarding()
        flows.append(first.flow)
        let restored = await launch(features, restored: .signedIn(dana))
        flows.append(restored.flow)

        // Assert
        XCTAssertEqual(flows, [.auth, .onboarding, .main, .main])
    }

    func testLaunch_WhenSignInIsRequiredAndOnboardingComesFirst_ShouldGoOnboardingThenAuthThenMain(
    ) async throws {
        // Arrange
        let features = AppFeatures(
            authentication: .required,
            onboarding: true,
            onboardingPlacement: .beforeSignIn
        )
        let first = await launch(features)

        // Act
        var flows = [first.flow]
        first.finishOnboarding()
        flows.append(first.flow)
        try await first.signIn(credentials)
        flows.append(first.flow)
        let signedOut = await launch(features)
        flows.append(signedOut.flow)

        // Assert: after the first run, a signed-out launch goes straight to sign-in.
        XCTAssertEqual(flows, [.onboarding, .auth, .main, .auth])
    }

    // MARK: - Per account

    func testLaunch_WhenAnotherAccountSignsInAfterOnboarding_ShouldShowItAgainForThem(
    ) async throws {
        // Arrange: Dana finishes onboarding on this phone.
        let features = AppFeatures(
            authentication: .required,
            onboarding: true,
            onboardingPlacement: .afterSignIn
        )
        let danaLaunch = await launch(features, signInAs: dana)
        try await danaLaunch.signIn(credentials)
        danaLaunch.finishOnboarding()

        // Act: later, Sam signs in on the same phone.
        let samLaunch = await launch(features, signInAs: sam)
        try await samLaunch.signIn(credentials)

        // Assert
        XCTAssertEqual(samLaunch.flow, .onboarding)
    }

    func testLaunch_WhenTheSameAccountSignsOutAndBackIn_ShouldNotRepeatOnboarding() async throws {
        // Arrange
        let features = AppFeatures(
            authentication: .required,
            onboarding: true,
            onboardingPlacement: .afterSignIn
        )
        let coordinator = await launch(features, signInAs: dana)
        try await coordinator.signIn(credentials)
        coordinator.finishOnboarding()

        // Act
        await coordinator.signOut()
        let afterSignOut = coordinator.flow
        let again = await launch(features, signInAs: dana)
        try await again.signIn(credentials)

        // Assert
        XCTAssertEqual(afterSignOut, .auth)
        XCTAssertEqual(again.flow, .main)
    }

    // MARK: - Helper

    private func launch(
        _ features: AppFeatures,
        restored: SessionState = .signedOut,
        signInAs user: AppUser? = nil
    ) async -> AppCoordinator {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let container = DependencyContainer.preview(
            features: features,
            session: FakeAuthSession(state: restored, signInResult: .success(user ?? dana)),
            onboarding: OnboardingStore(defaults: defaults)
        )
        let coordinator = AppCoordinator(container: container)
        await coordinator.start()
        return coordinator
    }
}
