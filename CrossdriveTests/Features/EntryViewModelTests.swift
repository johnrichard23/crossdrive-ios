@testable import Crossdrive
import DataLayer
import XCTest

@MainActor
final class EntryViewModelTests: XCTestCase {
    private struct Rig {
        var viewModel: EntryViewModel
        var requests: Recorder<String>
        var signIns: Recorder<String>
    }

    /// `handler` answers the account endpoints; `signIn` is the coordinator's sign-in.
    private func makeRig(
        trip: GateTrip? = nil,
        handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse = { _ in .json("{}") },
        signIn: @escaping @Sendable (Credentials) async throws -> Void = { _ in }
    ) -> Rig {
        let requests = Recorder<String>()
        let signIns = Recorder<String>()
        let client = StubHTTPClient { endpoint in
            requests.add(endpoint.path)
            return try await handler(endpoint)
        }
        let viewModel = EntryViewModel(
            trip: trip,
            accountAPI: AccountAPI(client: client),
            imageLoader: FakeImageLoader(),
            signIn: { credentials in
                signIns.add(credentials.email)
                try await signIn(credentials)
            }
        )
        return Rig(viewModel: viewModel, requests: requests, signIns: signIns)
    }

    // MARK: Email step

    func testContinueWithEmail_WhenEmailIsBad_ShouldAskNothingAndFocusTheEmail() async {
        // Arrange
        let rig = makeRig()
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
        let rig = makeRig { _ in .json(#"{"exists": true}"#) }
        rig.viewModel.email = " joy@example.com "

        // Act
        await rig.viewModel.continueWithEmail()

        // Assert
        XCTAssertEqual(rig.viewModel.path, [.password])
        XCTAssertEqual(rig.viewModel.trimmedEmail, "joy@example.com")
    }

    func testContinueWithEmail_WhenEmailIsNew_ShouldShowTheCreateStep() async {
        // Arrange
        let rig = makeRig { _ in .json(#"{"exists": false}"#) }
        rig.viewModel.email = "new@example.com"

        // Act
        await rig.viewModel.continueWithEmail()

        // Assert
        XCTAssertEqual(rig.viewModel.path, [.create])
    }

    func testContinueWithEmail_WhenTheAnswerCannotBeHad_ShouldAskForThePasswordNotCreateAnAccount(
    ) async {
        // Arrange
        let rig = makeRig { _ in .json("{}", status: 500) }
        rig.viewModel.email = "joy@example.com"

        // Act
        await rig.viewModel.continueWithEmail()

        // Assert
        XCTAssertEqual(rig.viewModel.path, [.password])
    }

    func testContinueWithEmail_WhenOffline_ShouldStayAndSayYouAreOffline() async {
        // Arrange
        let rig = makeRig { _ in throw NetworkError.noConnection }
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
        let rig = makeRig { _ in
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
        let rig = makeRig()
        rig.viewModel.email = "joy@example.com"

        // Act
        let field = await rig.viewModel.signInTapped()

        // Assert
        XCTAssertEqual(field, .password)
        XCTAssertTrue(rig.signIns.values.isEmpty)
    }

    func testSignInTapped_WhenPasswordIsRight_ShouldSignInWithTheTrimmedEmail() async {
        // Arrange
        let rig = makeRig()
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
        let rig = makeRig(signIn: { _ in throw AuthError.invalidCredentials })
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
        let rig = makeRig(signIn: { _ in throw NetworkError.client(status: 429, message: nil) })
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
        let rig = makeRig(signIn: { _ in throw AuthError.accountLocked })
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
        let rig = makeRig(signIn: { _ in throw NetworkError.server(status: 500, message: nil) })
        rig.viewModel.password = "fine"

        // Act
        let field = await rig.viewModel.signInTapped()

        // Assert
        XCTAssertNil(field)
        XCTAssertNil(rig.viewModel.passwordError)
        XCTAssertNotNil(rig.viewModel.formError)
    }

    // MARK: Create step

    func testCreateAccountTapped_WhenNameIsEmpty_ShouldFocusTheName() async {
        // Arrange
        let rig = makeRig()
        rig.viewModel.password = "longenough"

        // Act
        let field = await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertEqual(field, .name)
        XCTAssertTrue(rig.requests.values.isEmpty)
    }

    func testCreateAccountTapped_WhenPasswordIsTooShort_ShouldSayHowManyCharactersItHas() async {
        // Arrange
        let rig = makeRig()
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "12345"

        // Act
        let field = await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertEqual(field, .password)
        XCTAssertEqual(rig.viewModel.passwordError, "Use at least 8 characters. This one has 5.")
    }

    func testCreateAccountTapped_WhenNotAgreed_ShouldNotCreateTheAccount() async {
        // Arrange
        let rig = makeRig()
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "longenough"
        rig.viewModel.hasAgreed = false

        // Act
        await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertNotNil(rig.viewModel.agreementError)
        XCTAssertTrue(rig.requests.values.isEmpty)
    }

    func testCreateAccountTapped_WhenAccountIsReady_ShouldSignInWithTheSameDetails() async {
        // Arrange
        let rig = makeRig { _ in .json(#"{"verificationRequired": false}"#) }
        rig.viewModel.email = "new@example.com"
        rig.viewModel.name = " Joy "
        rig.viewModel.password = "longenough"

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
        let rig = makeRig { _ in .json(#"{"verificationRequired": true}"#) }
        rig.viewModel.email = "new@example.com"
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "longenough"

        // Act
        await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertEqual(rig.viewModel.path, [.checkEmail])
        XCTAssertTrue(rig.signIns.values.isEmpty)
    }

    func testCreateAccountTapped_WhenTheEmailAlreadyHasAnAccount_ShouldMoveToThePasswordStep(
    ) async {
        // Arrange
        let rig = makeRig { _ in .json(#"{"message": "exists"}"#, status: 409) }
        rig.viewModel.email = "joy@example.com"
        rig.viewModel.name = "Joy"
        rig.viewModel.password = "longenough"
        rig.viewModel.path = [.create]

        // Act
        await rig.viewModel.createAccountTapped()

        // Assert
        XCTAssertEqual(rig.viewModel.path, [.password])
        XCTAssertEqual(rig.viewModel.password, "")
        XCTAssertNotNil(rig.viewModel.formError)
    }

    // MARK: Reset and photos

    func testSendResetLinkTapped_WhenEmailIsGood_ShouldTellThemWithoutSayingIfTheAccountExists(
    ) async {
        // Arrange
        let rig = makeRig()
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
        let rig = makeRig { _ in .json(SampleStub.welcomePhotosJSON) }

        // Act
        await rig.viewModel.loadMedia(scale: 2)

        // Assert
        XCTAssertEqual(rig.viewModel.photos.count, 4)
    }

    func testLoadMedia_WhenFewerThanFourComeOrTheCallFails_ShouldShowNoMosaic() async {
        // Arrange
        let rig = makeRig { _ in .json(#"{"photos": ["https://example.com/a.jpg"]}"#) }

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
