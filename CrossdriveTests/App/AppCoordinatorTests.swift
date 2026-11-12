@testable import Crossdrive
import XCTest

@MainActor
final class AppCoordinatorTests: XCTestCase {
    private let suiteName = "AppCoordinatorTests"
    private let user = SessionState.signedIn(AppUser(id: "1"))

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testFlow_WhenNotStarted_ShouldBeLaunching() {
        // Act
        let coordinator = makeCoordinator(AppFeatures())

        // Assert
        XCTAssertEqual(coordinator.flow, .launching)
    }

    func testStart_WhenGuestFirstAndOnboardingOff_ShouldShowMain() async {
        // Arrange
        let coordinator = makeCoordinator(AppFeatures(authentication: .optional))

        // Act
        await coordinator.start()

        // Assert
        XCTAssertEqual(coordinator.flow, .main)
    }

    func testStart_WhenSignInRequiredAndNoSession_ShouldShowAuth() async {
        // Arrange
        let coordinator = makeCoordinator(AppFeatures(authentication: .required))

        // Act
        await coordinator.start()

        // Assert
        XCTAssertEqual(coordinator.flow, .auth)
    }

    func testStart_WhenSignInRequiredAndSessionRestores_ShouldShowMain() async {
        // Arrange
        let coordinator = makeCoordinator(
            AppFeatures(authentication: .required),
            session: FakeAuthSession(state: user)
        )

        // Act
        await coordinator.start()

        // Assert
        XCTAssertEqual(coordinator.flow, .main)
    }

    func testStart_WhenOnboardingOn_ShouldShowOnboardingFirst() async {
        // Arrange
        let coordinator = makeCoordinator(AppFeatures(onboarding: true))

        // Act
        await coordinator.start()

        // Assert
        XCTAssertEqual(coordinator.flow, .onboarding)
    }

    func testFinishOnboarding_WhenOnboardingShowing_ShouldShowMainAndRememberIt() async {
        // Arrange
        let coordinator = makeCoordinator(AppFeatures(onboarding: true))
        await coordinator.start()

        // Act
        coordinator.finishOnboarding()

        // Assert
        XCTAssertEqual(coordinator.flow, .main)
        XCTAssertTrue(coordinator.container.onboarding.isDone(for: .signedOut))
    }

    func testFinishOnboarding_WhenSignInRequired_ShouldContinueToAuth() async {
        // Arrange: onboarding before sign-in, nobody signed in yet.
        let features = AppFeatures(
            authentication: .required,
            onboarding: true,
            onboardingPlacement: .beforeSignIn
        )
        let coordinator = makeCoordinator(features)
        await coordinator.start()

        // Act
        coordinator.finishOnboarding()

        // Assert
        XCTAssertEqual(coordinator.flow, .auth)
    }

    func testStart_WhenCalledAgainAfterFinishing_ShouldNotRouteAgain() async {
        // Arrange
        let coordinator = makeCoordinator(AppFeatures(onboarding: true))
        await coordinator.start()
        coordinator.finishOnboarding()

        // Act
        await coordinator.start()

        // Assert
        XCTAssertEqual(coordinator.flow, .main)
    }

    private func makeCoordinator(
        _ features: AppFeatures,
        session: any AuthSession = NoAuthSession()
    ) -> AppCoordinator {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let container = DependencyContainer.preview(
            features: features,
            session: session,
            onboarding: OnboardingStore(defaults: defaults)
        )
        return AppCoordinator(container: container)
    }
}
