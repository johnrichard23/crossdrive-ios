@testable import Crossdrive
import DataLayer
import XCTest

final class AppLogTests: XCTestCase {
    func testSummary_WhenTheServerEchoesUserData_ShouldKeepOnlyTypeAndStatus() {
        // Arrange
        let error = NetworkError.client(status: 422, message: "dana@example.com is already taken")

        // Act
        let summary = AppLog.summary(error)

        // Assert
        XCTAssertEqual(summary, "NetworkError 422")
    }

    func testSummary_WhenTheReplyCouldNotBeRead_ShouldNotIncludeTheFieldText() {
        // Act
        let summary = AppLog
            .summary(NetworkError.decoding("Missing \"email\" for dana@example.com"))

        // Assert
        XCTAssertEqual(summary, "NetworkError")
    }

    func testSummary_WhenTheErrorIsNotANetworkError_ShouldNameItsType() {
        // Act
        let summary = AppLog.summary(AuthError.invalidCredentials)

        // Assert
        XCTAssertEqual(summary, "AuthError")
    }
}
