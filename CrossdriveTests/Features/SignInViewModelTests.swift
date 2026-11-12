@testable import Crossdrive
import DataLayer
import XCTest

@MainActor
final class SignInViewModelTests: XCTestCase {
    // MARK: - Validation

    func testSubmit_WhenEmailIsEmpty_ShouldAskForItWithoutSigningIn() async {
        // Arrange
        let calls = Recorder<Credentials>()
        let viewModel = SignInViewModel { calls.add($0) }
        viewModel.password = "secret"

        // Act
        let field = await viewModel.submit()

        // Assert
        XCTAssertEqual(field, .email)
        XCTAssertNotNil(viewModel.emailError)
        XCTAssertTrue(calls.values.isEmpty)
    }

    func testSubmit_WhenEmailHasNoDomain_ShouldAskForAValidEmail() async {
        // Arrange
        let viewModel = SignInViewModel { _ in }
        viewModel.email = "dana@"
        viewModel.password = "secret"

        // Act
        let field = await viewModel.submit()

        // Assert
        XCTAssertEqual(field, .email)
    }

    func testSubmit_WhenPasswordIsEmpty_ShouldAskForIt() async {
        // Arrange
        let viewModel = SignInViewModel { _ in }
        viewModel.email = "dana@example.com"

        // Act
        let field = await viewModel.submit()

        // Assert
        XCTAssertEqual(field, .password)
        XCTAssertNil(viewModel.emailError)
        XCTAssertNotNil(viewModel.passwordError)
    }

    func testSubmit_WhenBothAreEmpty_ShouldFocusTheFirstField() async {
        // Arrange
        let viewModel = SignInViewModel { _ in }

        // Act
        let field = await viewModel.submit()

        // Assert
        XCTAssertEqual(field, .email)
        XCTAssertNotNil(viewModel.passwordError)
    }

    func testEmailDidEndEditing_WhenEmailIsFixed_ShouldClearTheError() {
        // Arrange
        let viewModel = SignInViewModel { _ in }
        viewModel.emailDidEndEditing()
        viewModel.email = "dana@example.com"

        // Act
        viewModel.emailDidEndEditing()

        // Assert
        XCTAssertNil(viewModel.emailError)
    }

    // MARK: - Signing in

    func testSubmit_WhenInputIsValid_ShouldSignInWithTheTrimmedEmail() async {
        // Arrange
        let calls = Recorder<Credentials>()
        let viewModel = SignInViewModel { calls.add($0) }
        viewModel.email = "  dana@example.com "
        viewModel.password = "secret"

        // Act
        let field = await viewModel.submit()

        // Assert
        XCTAssertNil(field)
        XCTAssertEqual(calls.values, [Credentials(email: "dana@example.com", password: "secret")])
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertNil(viewModel.formError)
    }

    func testSubmit_WhenCredentialsAreWrong_ShouldShowOneMessageAndFocusThePassword() async {
        // Arrange
        let viewModel = SignInViewModel { _ in throw AuthError.invalidCredentials }
        viewModel.email = "dana@example.com"
        viewModel.password = "nope"

        // Act
        let field = await viewModel.submit()

        // Assert
        XCTAssertEqual(field, .password)
        XCTAssertEqual(viewModel.formError, AuthError.invalidCredentials.userMessage)
        XCTAssertNil(viewModel.emailError, "must not hint at which of the two was wrong")
        XCTAssertEqual(viewModel.failureCount, 1)
    }

    func testSubmit_WhenOffline_ShouldShowThePlainMessage() async {
        // Arrange
        let viewModel = SignInViewModel { _ in throw NetworkError.noConnection }
        viewModel.email = "dana@example.com"
        viewModel.password = "secret"

        // Act
        let field = await viewModel.submit()

        // Assert
        XCTAssertNil(field)
        XCTAssertEqual(viewModel.formError, NetworkError.noConnection.userMessage)
    }

    func testSubmit_WhenTheNextAttemptSucceeds_ShouldClearTheOldMessage() async {
        // Arrange
        let calls = Counter()
        let viewModel = SignInViewModel { _ in
            if calls.next() == 1 {
                throw NetworkError.noConnection
            }
        }
        viewModel.email = "dana@example.com"
        viewModel.password = "secret"
        await viewModel.submit()

        // Act
        await viewModel.submit()

        // Assert
        XCTAssertNil(viewModel.formError)
    }

    func testSubmit_WhenAlreadySigningIn_ShouldSendOnlyOneRequest() async {
        // Arrange: the first attempt waits for the server.
        let started = Gate()
        let release = Gate()
        let calls = Counter()
        let viewModel = SignInViewModel { _ in
            _ = calls.next()
            await started.open()
            await release.wait()
        }
        viewModel.email = "dana@example.com"
        viewModel.password = "secret"
        let first = Task { await viewModel.submit() }
        await started.wait()

        // Act
        await viewModel.submit()
        await release.open()
        _ = await first.value

        // Assert
        XCTAssertEqual(calls.next(), 2, "signIn should have been called exactly once before this")
    }
}
