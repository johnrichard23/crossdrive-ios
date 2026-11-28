@testable import Crossdrive
import DataLayer
import XCTest

/// Giving as a guest: signing in as a step of the sheet, leaving it, and what
/// stays put while the pledge is sending.
@MainActor
final class GiveViewModelSignInTests: XCTestCase, GiveTestRig {
    func testShowsSteps_WhenSignedIn_ShouldHideTheRowAndGoStraightToThePledge() async {
        // Arrange
        let viewModel = makeViewModel()

        // Act
        await viewModel.continueTapped()

        // Assert
        XCTAssertFalse(viewModel.showsSteps)
        XCTAssertEqual(viewModel.step, .pledge)
    }

    func testContinueTapped_WhenAGuestSignsIn_ShouldSaveThePledgeOnlyAfterSigningIn() async {
        // Arrange
        let posts = Counter()
        let signIn = SignInSpy()
        let viewModel = makeViewModel(signIn: signIn) { _ in
            _ = posts.next()
            return .json(pledgeJSON)
        }

        // Act
        await viewModel.continueTapped()
        let onSignInStep = (viewModel.step, viewModel.stepIndex, viewModel.signIn != nil)
        await signIn.finish()

        // Assert
        XCTAssertTrue(viewModel.showsSteps)
        XCTAssertEqual(viewModel.stepTitles, ["Amount", "Sign in", "Pledge"])
        XCTAssertEqual(onSignInStep.0, .signIn)
        XCTAssertEqual(onSignInStep.1, 1)
        XCTAssertTrue(onSignInStep.2)
        XCTAssertEqual(signIn.reminder?.title, "₱800 a month")
        XCTAssertEqual(viewModel.step, .pledge)
        XCTAssertEqual(viewModel.stepIndex, 2)
        XCTAssertEqual(posts.next(), 2)
    }

    func testBackToAmount_WhenAGuestLeavesSignIn_ShouldKeepTheAmountAndSaveNothing() async {
        // Arrange
        let posts = Counter()
        let viewModel = makeViewModel(signIn: SignInSpy()) { _ in
            _ = posts.next()
            return .json(pledgeJSON)
        }
        viewModel.choose(1200)
        await viewModel.continueTapped()

        // Act
        viewModel.backToAmount()

        // Assert
        XCTAssertEqual(viewModel.step, .amount)
        XCTAssertEqual(viewModel.pesos, 1200)
        XCTAssertNil(viewModel.signIn)
        XCTAssertEqual(posts.next(), 1)
    }

    func testBackToAmount_WhenTheSignInFinishesAfterwards_ShouldDropItAndSaveNothing() async {
        // Arrange: the guest leaves the sign-in step while it is still sending.
        let posts = Counter()
        let signIn = SignInSpy()
        let viewModel = makeViewModel(signIn: signIn) { _ in
            _ = posts.next()
            return .json(pledgeJSON)
        }
        await viewModel.continueTapped()
        viewModel.backToAmount()

        // Act
        let wentOn = await signIn.finish()

        // Assert
        XCTAssertFalse(wentOn)
        XCTAssertEqual(viewModel.step, .amount)
        XCTAssertEqual(posts.next(), 1)
    }

    func testContinueTapped_WhenTheAmountChangesAfterAFailure_ShouldKeepOneKey() async {
        // Arrange: every save fails, so each Continue sends again. A lost reply
        // may still have saved the first pledge, so a new key could save two.
        let keys = Recorder<String>()
        let viewModel = makeViewModel { endpoint in
            keys.add(endpoint.headers["Idempotency-Key"] ?? "")
            return .json("{}", status: 500)
        }

        // Act
        await viewModel.continueTapped()
        viewModel.choose(1200)
        await viewModel.continueTapped()

        // Assert
        XCTAssertEqual(keys.values.count, 2)
        XCTAssertEqual(Set(keys.values).count, 1)
    }

    func testChoose_WhileThePledgeIsSending_ShouldKeepTheAmount() async {
        // Arrange
        let release = Gate()
        let viewModel = makeViewModel { _ in
            await release.wait()
            return .json(pledgeJSON)
        }
        let sending = Task { await viewModel.continueTapped() }
        await Task.yield()

        // Act
        viewModel.choose(1200)
        viewModel.setFrequency(.yearly)
        await release.open()
        await sending.value

        // Assert
        XCTAssertEqual(viewModel.savedGift, Gift(frequency: .monthly, pesos: 800))
        XCTAssertEqual(viewModel.gift, Gift(frequency: .monthly, pesos: 800))
    }

    func testPresets_ForAYearlyGiftOutsideTheSchoolFund_ShouldCountTwelveMonths() {
        // Arrange
        let viewModel = makeViewModel(ministry: ministry(kind: .bibleStudy))

        // Act
        viewModel.setFrequency(.yearly)

        // Assert
        XCTAssertEqual(viewModel.pesos, 9600)
        XCTAssertEqual(viewModel.presets, [3600, 6000, 9600, 14400])
    }

    func testContinueTapped_WhenTheGuestSignedInElsewhere_ShouldSkipSignIn() async {
        // Arrange: a guest when the sheet opened, signed in before Continue.
        let signIn = SignInSpy()
        let guest = GuestFlag()
        let viewModel = makeViewModel(signIn: signIn, guest: guest)
        guest.isGuest = false

        // Act
        await viewModel.continueTapped()

        // Assert
        XCTAssertTrue(viewModel.showsSteps)
        XCTAssertNil(signIn.reminder)
        XCTAssertEqual(viewModel.step, .pledge)
    }

    func testClose_WhenTheSignInFinishesAfterwards_ShouldSaveNothing() async {
        // Arrange: the guest swipes the sheet away while signing in.
        let posts = Counter()
        let signIn = SignInSpy()
        let viewModel = makeViewModel(signIn: signIn) { _ in
            _ = posts.next()
            return .json(pledgeJSON)
        }
        await viewModel.continueTapped()
        viewModel.close()

        // Act
        let wentOn = await signIn.finish()

        // Assert
        XCTAssertFalse(wentOn)
        XCTAssertNil(viewModel.pledge)
        XCTAssertEqual(posts.next(), 1)
    }

    func testContinueTapped_WhenTheSignedInGuestsPledgeFails_ShouldNotAskToSignInAgain() async {
        // Arrange: the pledge fails once, then saves.
        let posts = Counter()
        let signIn = SignInSpy()
        let viewModel = makeViewModel(signIn: signIn) { _ in
            posts.next() == 1 ? .json("{}", status: 500) : .json(pledgeJSON)
        }
        await viewModel.continueTapped()
        await signIn.finish()
        let afterFailure = viewModel.step

        // Act
        await viewModel.continueTapped()

        // Assert
        XCTAssertEqual(afterFailure, .amount)
        XCTAssertEqual(viewModel.step, .pledge)
        XCTAssertEqual(viewModel.stepTitles, ["Amount", "Sign in", "Pledge"])
    }
}
