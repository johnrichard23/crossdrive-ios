@testable import Crossdrive
import DataLayer
import XCTest

final class ErrorUserMessageTests: XCTestCase {
    func testUserMessage_WhenServerFails_ShouldNotShowTheStatusCode() {
        // Act
        let message = NetworkError.server(status: 503, message: nil).userMessage

        // Assert
        XCTAssertFalse(message.contains("503"))
        XCTAssertFalse(message.isEmpty)
    }

    func testUserMessage_WhenRequestIsRejectedWithAMessage_ShouldShowTheServersWords() {
        // Act
        let message = NetworkError.client(status: 422, message: "That email is taken.").userMessage

        // Assert
        XCTAssertEqual(message, "That email is taken.")
    }

    func testUserMessage_WhenRequestIsRejectedWithoutAMessage_ShouldShowGenericText() {
        // Act
        let message = NetworkError.client(status: 422, message: "").userMessage

        // Assert
        XCTAssertFalse(message.isEmpty)
        XCTAssertFalse(message.contains("422"))
    }

    func testUserMessage_WhenOffline_ShouldDifferFromAServerProblem() {
        // Act
        let offline = NetworkError.noConnection.userMessage
        let server = NetworkError.server(status: 500, message: nil).userMessage

        // Assert
        XCTAssertNotEqual(offline, server)
    }

    func testUserMessage_WhenErrorIsNotANetworkError_ShouldShowGenericText() {
        // Act
        let message = CocoaError(.fileNoSuchFile).userMessage

        // Assert
        XCTAssertFalse(message.isEmpty)
    }
}
