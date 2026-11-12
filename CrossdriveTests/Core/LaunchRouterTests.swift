@testable import Crossdrive
import XCTest

/// One test per authentication × onboarding × session case of the launch router.
final class LaunchRouterTests: XCTestCase {
    private let user = SessionState.signedIn(AppUser(id: "1"))

    // MARK: - No accounts

    func testFlow_WhenNoAccountsAndOnboardingPending_ShouldShowOnboarding() {
        // Act
        let flow = route(.none, onboarding: true, done: false)

        // Assert
        XCTAssertEqual(flow, .onboarding)
    }

    func testFlow_WhenNoAccountsAndOnboardingDone_ShouldShowMain() {
        // Act
        let flow = route(.none, onboarding: true, done: true)

        // Assert
        XCTAssertEqual(flow, .main)
    }

    func testFlow_WhenNoAccountsAndOnboardingOff_ShouldShowMain() {
        // Act
        let flow = route(.none, onboarding: false, done: false)

        // Assert
        XCTAssertEqual(flow, .main)
    }

    // MARK: - Optional accounts

    func testFlow_WhenOptionalAndGuestAndOnboardingPending_ShouldShowOnboarding() {
        // Act
        let flow = route(.optional, onboarding: true, done: false, session: .signedOut)

        // Assert
        XCTAssertEqual(flow, .onboarding)
    }

    func testFlow_WhenOptionalAndSignedInAndOnboardingPending_ShouldShowOnboarding() {
        // Act
        let flow = route(.optional, onboarding: true, done: false, session: user)

        // Assert
        XCTAssertEqual(flow, .onboarding)
    }

    func testFlow_WhenOptionalAndOnboardingDone_ShouldShowMain() {
        // Act
        let flow = route(.optional, onboarding: true, done: true)

        // Assert
        XCTAssertEqual(flow, .main)
    }

    func testFlow_WhenOptionalAndGuestAndOnboardingOff_ShouldShowMainAsGuest() {
        // Act
        let flow = route(.optional, onboarding: false, done: false, session: .signedOut)

        // Assert
        XCTAssertEqual(flow, .main)
    }

    // MARK: - Required accounts

    func testFlow_WhenRequiredAndSignedOutAndOnboardingBeforeSignIn_ShouldShowOnboarding() {
        // Act
        let flow = route(
            .required, onboarding: true, done: false, placement: .beforeSignIn,
            session: .signedOut
        )

        // Assert
        XCTAssertEqual(flow, .onboarding)
    }

    func testFlow_WhenRequiredAndSignedOutAndOnboardingAfterSignIn_ShouldShowAuth() {
        // Act
        let flow = route(
            .required, onboarding: true, done: false, placement: .afterSignIn,
            session: .signedOut
        )

        // Assert
        XCTAssertEqual(flow, .auth)
    }

    func testFlow_WhenRequiredAndSignedOutAndOnboardingOff_ShouldShowAuth() {
        // Act
        let flow = route(.required, onboarding: false, done: false, session: .signedOut)

        // Assert
        XCTAssertEqual(flow, .auth)
    }

    func testFlow_WhenRequiredAndSignedOutAndOnboardingAlreadyDone_ShouldShowAuth() {
        // Act
        let flow = route(
            .required, onboarding: true, done: true, placement: .beforeSignIn,
            session: .signedOut
        )

        // Assert
        XCTAssertEqual(flow, .auth)
    }

    func testFlow_WhenRequiredAndSignedInAndOnboardingPending_ShouldShowOnboarding() {
        // Act
        let flow = route(.required, onboarding: true, done: false, session: user)

        // Assert
        XCTAssertEqual(flow, .onboarding)
    }

    func testFlow_WhenRequiredAndSignedInAndOnboardingDone_ShouldShowMain() {
        // Act
        let flow = route(.required, onboarding: true, done: true, session: user)

        // Assert
        XCTAssertEqual(flow, .main)
    }

    func testFlow_WhenRequiredAndSignedInAndOnboardingOff_ShouldShowMain() {
        // Act
        let flow = route(.required, onboarding: false, done: false, session: user)

        // Assert
        XCTAssertEqual(flow, .main)
    }

    // MARK: - Helper

    private func route(
        _ authentication: AppFeatures.Authentication,
        onboarding: Bool,
        done: Bool,
        placement: AppFeatures.OnboardingPlacement = .afterSignIn,
        session: SessionState = .signedOut
    ) -> AppFlow {
        LaunchRouter.flow(
            features: AppFeatures(
                authentication: authentication,
                onboarding: onboarding,
                onboardingPlacement: placement
            ),
            session: session,
            onboardingDone: done
        )
    }
}
