@testable import Crossdrive
import DataLayer
import XCTest

/// The create-account step and "Check your email".
@MainActor
final class EntryAccountCreationTests: XCTestCase {
    // MARK: Create step

    func testCreateAccountTapped_WhenNameIsEmpty_ShouldFocusTheName() async {
        // Arrange
        let rig = makeEntryRig()
        rig.viewModel.password = "longenough"

        // Act
        let field = await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertEqual(field, .name)
        XCTAssertTrue(rig.requests.values.isEmpty)
    }

    func testCreateAccountTapped_WhenPasswordIsTooShort_ShouldSayHowManyCharactersItHas() async {
        // Arrange
        let rig = makeEntryRig()
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "12345"

        // Act
        let field = await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertEqual(field, .password)
        XCTAssertEqual(rig.viewModel.passwordError, "Use at least 8 characters. This one has 5.")
    }

    func testHasAgreed_WhenTheSheetOpens_ShouldStartUnticked() {
        XCTAssertFalse(makeEntryRig().viewModel.hasAgreed)
    }

    func testCreateAccountTapped_WhenNotAgreed_ShouldNotCreateTheAccount() async {
        // Arrange
        let rig = makeEntryRig()
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "longenough"

        // Act
        await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertNotNil(rig.viewModel.agreementError)
        XCTAssertTrue(rig.requests.values.isEmpty)
    }

    func testCreateAccountTapped_WhenAccountIsReady_ShouldSignInWithTheSameDetails() async {
        // Arrange
        let rig = makeEntryRig { _ in .json(#"{"verificationRequired": false}"#) }
        rig.viewModel.email = "new@example.com"
        rig.viewModel.name = " Joy "
        rig.viewModel.password = "longenough"
        rig.viewModel.hasAgreed = true

        // Act
        let field = await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertNil(field)
        XCTAssertEqual(rig.requests.values, ["auth/sign-up"])
        XCTAssertEqual(rig.signIns.values, ["new@example.com"])
    }

    func testCreateAccountTapped_WhenTheEmailMustBeChecked_ShouldShowCheckYourEmailAndNotSignIn(
    ) async {
        // Arrange
        let rig = makeEntryRig { _ in .json(#"{"verificationRequired": true}"#) }
        rig.viewModel.email = "new@example.com"
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "longenough"
        rig.viewModel.hasAgreed = true

        // Act
        await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertEqual(rig.viewModel.path, [.checkEmail])
        XCTAssertTrue(rig.signIns.values.isEmpty)
    }

    func testCreateAccountTapped_WhenTheEmailAlreadyHasAnAccount_ShouldMoveToThePasswordStep(
    ) async {
        // Arrange
        let rig = makeEntryRig { _ in .json(#"{"message": "exists"}"#, status: 409) }
        rig.viewModel.email = "joy@example.com"
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "longenough"
        rig.viewModel.hasAgreed = true
        rig.viewModel.path = [.create]

        // Act
        await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertEqual(rig.viewModel.path, [.password])
        XCTAssertEqual(rig.viewModel.password, "")
        XCTAssertNotNil(rig.viewModel.formError)
    }

    func testCreateAccountTapped_WhenTheFieldsChangeWhileSigningUp_ShouldSignInWithWhatWasSent(
    ) async {
        // Arrange
        let started = Gate()
        let release = Gate()
        let rig = makeEntryRig { _ in
            await started.open()
            await release.wait()
            return .json(#"{"verificationRequired": false}"#)
        }
        rig.viewModel.email = "new@example.com"
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "longenough"
        rig.viewModel.hasAgreed = true
        let creating = Task { await rig.viewModel.createAccountTapped() }
        await started.wait()

        // Act
        rig.viewModel.email = "other@example.com"
        rig.viewModel.password = "changed!!"
        await release.open()
        await creating.value

        // Assert
        XCTAssertEqual(rig.signIns.values, ["new@example.com"])
    }

    func testCreateAccountTapped_WhenTheReplyHasNoVerificationAnswer_ShouldNotSignIn() async {
        // Arrange
        let rig = makeEntryRig { _ in .json("{}") }
        rig.viewModel.email = "new@example.com"
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "longenough"
        rig.viewModel.hasAgreed = true

        // Act
        await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertTrue(rig.signIns.values.isEmpty)
        XCTAssertNotNil(rig.viewModel.formError)
    }

    // MARK: Check your email

    func testResumeAfterVerification_WhenTheEmailWasConfirmed_ShouldSignInWithTheSignUpDetails(
    ) async {
        // Arrange
        let rig = makeEntryRig { _ in .json(#"{"verificationRequired": true}"#) }
        rig.viewModel.email = "new@example.com"
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "longenough"
        rig.viewModel.hasAgreed = true
        await rig.viewModel.createAccountTapped()

        // Act
        await rig.viewModel.resumeAfterVerification()

        // Assert
        XCTAssertEqual(rig.signIns.values, ["new@example.com"])
    }

    func testResumeAfterVerification_WhenStillUnconfirmed_ShouldStayWithoutAnError() async {
        // Arrange
        let rig = makeEntryRig(
            handler: { _ in .json(#"{"verificationRequired": true}"#) },
            signIn: { _ in throw NetworkError.client(status: 403, message: nil) }
        )
        rig.viewModel.email = "new@example.com"
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "longenough"
        rig.viewModel.hasAgreed = true
        await rig.viewModel.createAccountTapped()

        // Act
        await rig.viewModel.resumeAfterVerification()

        // Assert
        XCTAssertEqual(rig.viewModel.path, [.checkEmail])
        XCTAssertNil(rig.viewModel.formError)
    }

    func testResumeAfterVerification_WhenNotOnCheckYourEmail_ShouldDoNothing() async {
        // Arrange
        let rig = makeEntryRig()

        // Act
        await rig.viewModel.resumeAfterVerification()

        // Assert
        XCTAssertTrue(rig.signIns.values.isEmpty)
    }
}
