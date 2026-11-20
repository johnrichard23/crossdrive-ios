@testable import Crossdrive
import DataLayer
import XCTest

@MainActor
final class EntryViewModelTests: XCTestCase {
    // MARK: Email step

    func testContinueWithEmail_WhenEmailIsBad_ShouldAskNothingAndFocusTheEmail() async {
        // Arrange
        let rig = makeEntryRig()
        rig.viewModel.email = "joy"

        // Act
        let field = await rig.viewModel.continueWithEmail()

        // Assert
        XCTAssertEqual(field, .email)
        XCTAssertNotNil(rig.viewModel.emailError)
        XCTAssertTrue(rig.requests.values.isEmpty)
        XCTAssertTrue(rig.viewModel.path.isEmpty)
    }

    func testContinueWithEmail_WhenEmailHasAnAccount_ShouldShowThePasswordStep() async {
        // Arrange
        let rig = makeEntryRig { _ in .json(#"{"exists": true}"#) }
        rig.viewModel.email = " joy@example.com "

        // Act
        await rig.viewModel.continueWithEmail()

        // Assert
        XCTAssertEqual(rig.viewModel.path, [.password])
        XCTAssertEqual(rig.viewModel.trimmedEmail, "joy@example.com")
    }

    func testContinueWithEmail_WhenEmailIsNew_ShouldShowTheCreateStep() async {
        // Arrange
        let rig = makeEntryRig { _ in .json(#"{"exists": false}"#) }
        rig.viewModel.email = "new@example.com"

        // Act
        await rig.viewModel.continueWithEmail()

        // Assert
        XCTAssertEqual(rig.viewModel.path, [.create])
    }

    func testContinueWithEmail_WhenTheServerFails_ShouldStayAndLetThemTryAgain() async {
        // Arrange
        let rig = makeEntryRig { _ in .json("{}", status: 500) }
        rig.viewModel.email = "joy@example.com"

        // Act
        let field = await rig.viewModel.continueWithEmail()

        // Assert
        XCTAssertNil(field)
        XCTAssertTrue(rig.viewModel.path.isEmpty)
        XCTAssertNotNil(rig.viewModel.formError)
        XCTAssertEqual(rig.viewModel.failureCount, 1)
    }

    func testContinueWithEmail_WhenTheReplyHasNoAnswer_ShouldNotTreatTheEmailAsNew() async {
        // Arrange
        let rig = makeEntryRig { _ in .json("{}") }
        rig.viewModel.email = "joy@example.com"

        // Act
        await rig.viewModel.continueWithEmail()

        // Assert
        XCTAssertTrue(rig.viewModel.path.isEmpty)
        XCTAssertNotNil(rig.viewModel.formError)
    }

    func testContinueWithEmail_WhenTheEmailIsEditedWhileAsking_ShouldDropTheOldAnswer() async {
        // Arrange
        let started = Gate()
        let release = Gate()
        let rig = makeEntryRig { _ in
            await started.open()
            await release.wait()
            return .json(#"{"exists": true}"#)
        }
        rig.viewModel.email = "joy@example.com"
        let asking = Task { await rig.viewModel.continueWithEmail() }
        await started.wait()

        // Act
        rig.viewModel.email = "someone.else@example.com"
        await release.open()
        await asking.value

        // Assert
        XCTAssertTrue(rig.viewModel.path.isEmpty)
    }

    func testContinueWithEmail_WhenOffline_ShouldStayAndSayYouAreOffline() async {
        // Arrange
        let rig = makeEntryRig { _ in throw NetworkError.noConnection }
        rig.viewModel.email = "joy@example.com"

        // Act
        await rig.viewModel.continueWithEmail()

        // Assert
        XCTAssertTrue(rig.viewModel.path.isEmpty)
        XCTAssertEqual(
            rig.viewModel.formError,
            "You're offline. Connect to the internet to sign in."
        )
    }

    func testContinueWithEmail_WhenTappedTwiceAtOnce_ShouldAskOnce() async {
        // Arrange
        let started = Gate()
        let release = Gate()
        let rig = makeEntryRig { _ in
            await started.open()
            await release.wait()
            return .json(#"{"exists": true}"#)
        }
        rig.viewModel.email = "joy@example.com"
        let first = Task { await rig.viewModel.continueWithEmail() }
        await started.wait()

        // Act
        await rig.viewModel.continueWithEmail()
        await release.open()
        await first.value

        // Assert
        XCTAssertEqual(rig.requests.values, ["auth/email-status"])
        XCTAssertEqual(rig.viewModel.path, [.password])
    }

    // MARK: Password step

    func testSignInTapped_WhenPasswordIsEmpty_ShouldFocusThePasswordWithoutSigningIn() async {
        // Arrange
        let rig = makeEntryRig()
        rig.viewModel.email = "joy@example.com"

        // Act
        let field = await rig.viewModel.signInTapped()

        // Assert
        XCTAssertEqual(field, .password)
        XCTAssertTrue(rig.signIns.values.isEmpty)
    }

    func testSignInTapped_WhenPasswordIsRight_ShouldSignInWithTheTrimmedEmail() async {
        // Arrange
        let rig = makeEntryRig()
        rig.viewModel.email = " joy@example.com "
        rig.viewModel.password = "correct horse"

        // Act
        let field = await rig.viewModel.signInTapped()

        // Assert
        XCTAssertNil(field)
        XCTAssertEqual(rig.signIns.values, ["joy@example.com"])
    }

    func testSignInTapped_WhenPasswordIsWrong_ShouldSayItDoesNotMatch() async {
        // Arrange
        let rig = makeEntryRig(signIn: { _ in throw AuthError.invalidCredentials })
        rig.viewModel.password = "nope"

        // Act
        let field = await rig.viewModel.signInTapped()

        // Assert
        XCTAssertEqual(field, .password)
        XCTAssertEqual(
            rig.viewModel.passwordError,
            "That password doesn't match. Try again, or reset it."
        )
        XCTAssertEqual(rig.viewModel.failureCount, 1)
    }

    func testSignInTapped_WhenTooManyTries_ShouldLockAndOfferTheReset() async {
        // Arrange
        let rig = makeEntryRig(signIn: { _ in
            throw NetworkError.client(status: 429, message: nil)
        })
        rig.viewModel.password = "nope"

        // Act
        await rig.viewModel.signInTapped()
        rig.viewModel.showReset()

        // Assert
        XCTAssertEqual(rig.viewModel.path, [.reset])
        XCTAssertFalse(rig.viewModel.isLocked, "showing the reset clears the lock message")
    }

    func testSignInTapped_WhenTooManyTries_ShouldShowThePausedMessage() async {
        // Arrange
        let rig = makeEntryRig(signIn: { _ in throw AuthError.accountLocked })
        rig.viewModel.password = "nope"

        // Act
        await rig.viewModel.signInTapped()

        // Assert
        XCTAssertTrue(rig.viewModel.isLocked)
        XCTAssertEqual(
            rig.viewModel.passwordError,
            "Too many tries, so sign-in is paused for 15 minutes. Reset your password to get back in now."
        )
    }

    func testSignInTapped_WhenTheServerFails_ShouldShowAPlainMessageNotAFieldError() async {
        // Arrange
        let rig = makeEntryRig(signIn: { _ in
            throw NetworkError.server(status: 500, message: nil)
        })
        rig.viewModel.password = "fine"

        // Act
        let field = await rig.viewModel.signInTapped()

        // Assert
        XCTAssertNil(field)
        XCTAssertNil(rig.viewModel.passwordError)
        XCTAssertNotNil(rig.viewModel.formError)
    }

    func testSignInTapped_WhenAnEarlierAttemptFailedWithAServerError_ShouldClearThatMessage(
    ) async {
        // Arrange
        let failures = Counter()
        let rig = makeEntryRig(signIn: { _ in
            if failures.next() == 1 {
                throw NetworkError.server(status: 500, message: nil)
            }
            throw AuthError.invalidCredentials
        })
        rig.viewModel.password = "nope"
        await rig.viewModel.signInTapped()
        XCTAssertNotNil(rig.viewModel.formError)

        // Act
        await rig.viewModel.signInTapped()

        // Assert
        XCTAssertNil(rig.viewModel.formError)
        XCTAssertNotNil(rig.viewModel.passwordError)
    }

    // MARK: Reset and photos

    func testSendResetLinkTapped_WhenEmailIsGood_ShouldTellThemWithoutSayingIfTheAccountExists(
    ) async {
        // Arrange
        let rig = makeEntryRig()
        rig.viewModel.email = "joy@example.com"

        // Act
        await rig.viewModel.sendResetLinkTapped()

        // Assert
        XCTAssertEqual(rig.requests.values, ["auth/forgot-password"])
        XCTAssertEqual(
            rig.viewModel.resetNotice,
            "If joy@example.com has an account, a link is on its way."
        )
    }

    func testLoadMedia_WhenFourPhotosCome_ShouldShowThemAll() async {
        // Arrange
        let rig = makeEntryRig { _ in .json(SampleStub.welcomePhotosJSON) }

        // Act
        await rig.viewModel.loadMedia(scale: 2)

        // Assert
        XCTAssertEqual(rig.viewModel.photos.count, 4)
    }

    func testLoadMedia_WhenFewerThanFourComeOrTheCallFails_ShouldShowNoMosaic() async {
        // Arrange
        let rig = makeEntryRig { _ in .json(#"{"photos": ["https://example.com/a.jpg"]}"#) }

        // Act
        await rig.viewModel.loadMedia(scale: 2)

        // Assert
        XCTAssertTrue(rig.viewModel.photos.isEmpty)
    }

    func testGateTrip_WhenBuiltFromAnEvent_ShouldJoinTheDateAndPlace() throws {
        // Arrange
        let dto = try JSONDecoder().decode(HomeDTO.self, from: Data(SampleStub.homeJSON().utf8))
        let event = try XCTUnwrap(HomeMapper().model(from: dto).trip?.event)

        // Act
        let trip = event.gateTrip

        // Assert
        XCTAssertEqual(trip.title, "Behia Mission Trip")
        XCTAssertEqual(trip.detail, "Dec 12 to 14 · Bagatao Island")
    }
}
