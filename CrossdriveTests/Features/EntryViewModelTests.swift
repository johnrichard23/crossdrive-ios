@testable import Crossdrive
import DataLayer
import XCTest

@MainActor
final class EntryViewModelTests: XCTestCase {
    // MARK: Email step

    func testContinueTapped_WhenEmailIsBad_ShouldStayAndFocusTheEmail() {
        // Arrange
        let rig = makeEntryRig()
        rig.viewModel.email = "joy"

        // Act
        let field = rig.viewModel.continueTapped()

        // Assert
        XCTAssertEqual(field, .email)
        XCTAssertNotNil(rig.viewModel.emailError)
        XCTAssertTrue(rig.viewModel.path.isEmpty)
    }

    func testContinueTapped_WhenEmailIsGood_ShouldShowThePasswordWithoutAskingTheServer() {
        // Arrange
        let rig = makeEntryRig()
        rig.viewModel.email = " joy@example.com "

        // Act
        let field = rig.viewModel.continueTapped()

        // Assert
        XCTAssertNil(field)
        XCTAssertEqual(rig.viewModel.path, [.password])
        XCTAssertEqual(rig.viewModel.trimmedEmail, "joy@example.com")
        XCTAssertTrue(rig.requests.values.isEmpty, "nothing may reveal who has an account")
    }

    func testCreateTapped_WhenEmailIsGood_ShouldShowTheCreateStepWithoutAskingTheServer() {
        // Arrange
        let rig = makeEntryRig()
        rig.viewModel.email = "new@example.com"

        // Act
        let field = rig.viewModel.createTapped()

        // Assert
        XCTAssertNil(field)
        XCTAssertEqual(rig.viewModel.path, [.create])
        XCTAssertTrue(rig.requests.values.isEmpty)
    }

    func testCreateTapped_WhenEmailIsBad_ShouldStayAndFocusTheEmail() {
        // Arrange
        let rig = makeEntryRig()
        rig.viewModel.email = ""

        // Act
        let field = rig.viewModel.createTapped()

        // Assert
        XCTAssertEqual(field, .email)
        XCTAssertTrue(rig.viewModel.path.isEmpty)
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
            "That email or password doesn't match. Try again, or reset it."
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

    func testLoadTripImage_WhenTheTripHasAPicture_ShouldLoadIt() async {
        // Arrange
        let trip = GateTrip(
            title: "Behia",
            detail: "",
            imageURL: URL(string: "https://example.com/a.jpg")
        )
        let rig = makeEntryRig(trip: trip)

        // Act
        await rig.viewModel.loadTripImage(scale: 2)

        // Assert
        XCTAssertNotNil(rig.viewModel.tripImage)
    }

    func testLoadTripImage_WhenThereIsNoTrip_ShouldLoadNothing() async {
        // Arrange
        let rig = makeEntryRig()

        // Act
        await rig.viewModel.loadTripImage(scale: 2)

        // Assert
        XCTAssertNil(rig.viewModel.tripImage)
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
