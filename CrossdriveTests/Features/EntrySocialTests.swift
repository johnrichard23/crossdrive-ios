import AuthenticationServices
@testable import Crossdrive
import DataLayer
import XCTest

/// "Continue with Facebook" on the sign-in sheet.
@MainActor
final class EntrySocialTests: XCTestCase {
    func testCanUseFacebook_WhenNotSetUpForTheBuild_ShouldBeFalse() {
        // Arrange
        let rig = makeEntryRig(facebook: UnavailableSocialSignIn())

        // Assert
        XCTAssertFalse(rig.viewModel.canUseFacebook)
    }

    func testFacebookTapped_WhenFacebookAgrees_ShouldSendItsTokenToTheServer() async {
        // Arrange
        let rig = makeEntryRig()

        // Act
        await rig.viewModel.facebookTapped()

        // Assert
        XCTAssertEqual(rig.socialSignIns.values, ["fake-token"])
        XCTAssertNil(rig.viewModel.formError)
    }

    func testFacebookTapped_WhenTheScreenIsClosed_ShouldStayQuietAndSendNothing() async {
        // Arrange
        let rig = makeEntryRig(
            facebook: FakeSocialSignIn(result: .failure(SocialSignInError.cancelled))
        )

        // Act
        await rig.viewModel.facebookTapped()

        // Assert
        XCTAssertTrue(rig.socialSignIns.values.isEmpty)
        XCTAssertNil(rig.viewModel.formError)
        XCTAssertEqual(rig.viewModel.failureCount, 0)
    }

    func testFacebookTapped_WhenFacebookFails_ShouldSayItAndCountTheFailure() async {
        // Arrange
        let rig = makeEntryRig(
            facebook: FakeSocialSignIn(result: .failure(SocialSignInError.missingToken))
        )

        // Act
        await rig.viewModel.facebookTapped()

        // Assert
        XCTAssertNotNil(rig.viewModel.formError)
        XCTAssertEqual(rig.viewModel.failureCount, 1)
        XCTAssertTrue(rig.socialSignIns.values.isEmpty)
    }

    func testFacebookTapped_WhenTheServerRefuses_ShouldShowItsMessage() async {
        // Arrange
        let rig = makeEntryRig(
            signInWithSocial: { _ in throw NetworkError.server(status: 500, message: nil) }
        )

        // Act
        await rig.viewModel.facebookTapped()

        // Assert
        XCTAssertNotNil(rig.viewModel.formError)
        XCTAssertFalse(rig.viewModel.isSubmitting)
    }

    // MARK: Apple

    func testAppleFinished_WhenAppleAgrees_ShouldSendItsTokenToTheServer() async {
        // Arrange
        let rig = makeEntryRig()
        let credential = SocialCredential(
            provider: .apple,
            token: "apple-token",
            nonce: "n1",
            accessToken: nil
        )

        // Act
        await rig.viewModel.appleFinished(.success(credential))

        // Assert
        XCTAssertEqual(rig.socialSignIns.values, ["apple-token"])
        XCTAssertNil(rig.viewModel.formError)
    }

    func testAppleFinished_WhenTheSheetWasClosed_ShouldStayQuiet() async {
        // Arrange
        let rig = makeEntryRig()

        // Act
        await rig.viewModel.appleFinished(.failure(SocialSignInError.cancelled))

        // Assert
        XCTAssertNil(rig.viewModel.formError)
        XCTAssertEqual(rig.viewModel.failureCount, 0)
    }

    func testAppleSignIn_WhenAppleSaysCancelled_ShouldBeCancelledNotAFailure() {
        // Act
        let error = AppleSignIn.mapped(ASAuthorizationError(.canceled))

        // Assert
        XCTAssertEqual(error as? SocialSignInError, .cancelled)
    }

    func testAppleSignIn_WhenAppleFailsAnotherWay_ShouldPassTheErrorOn() {
        // Act
        let error = AppleSignIn.mapped(ASAuthorizationError(.failed))

        // Assert
        XCTAssertNil(error as? SocialSignInError)
    }

    func testAppleSignIn_WhenPreparingARequest_ShouldAskForNameAndEmailWithAFreshNonce() {
        // Arrange
        let request = ASAuthorizationAppleIDProvider().createRequest()

        // Act
        let first = AppleSignIn.prepare(request)
        let second = AppleSignIn.prepare(ASAuthorizationAppleIDProvider().createRequest())

        // Assert
        XCTAssertEqual(request.requestedScopes, [.fullName, .email])
        XCTAssertEqual(request.nonce, first)
        XCTAssertNotEqual(first, second)
    }
}
