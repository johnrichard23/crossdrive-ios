@testable import Crossdrive
import XCTest

final class AppEnvironmentTests: XCTestCase {
    func testInit_WhenValuesAreValid_ShouldReadKindAndURL() throws {
        // Arrange
        let info = ["APP_ENVIRONMENT": "staging", "API_BASE_URL": "https://api.staging.example.com"]

        // Act
        let environment = try AppEnvironment(info: info)

        // Assert
        XCTAssertEqual(environment.kind, .staging)
        XCTAssertEqual(environment.apiBaseURL.absoluteString, "https://api.staging.example.com")
    }

    func testInit_WhenURLIsMissing_ShouldThrowMissing() {
        // Arrange
        let info = ["APP_ENVIRONMENT": "debug"]

        // Act
        let error = configurationError(for: info)

        // Assert
        XCTAssertEqual(error, .missing(key: "API_BASE_URL"))
    }

    func testInit_WhenURLIsBlank_ShouldThrowMissing() {
        // Arrange: what an undefined build setting expands to.
        let info = ["APP_ENVIRONMENT": "debug", "API_BASE_URL": "  "]

        // Act
        let error = configurationError(for: info)

        // Assert
        XCTAssertEqual(error, .missing(key: "API_BASE_URL"))
    }

    func testInit_WhenKindIsUnknown_ShouldThrowInvalid() {
        // Arrange
        let info = ["APP_ENVIRONMENT": "production", "API_BASE_URL": "https://api.example.com"]

        // Act
        let error = configurationError(for: info)

        // Assert
        XCTAssertEqual(error, .invalid(key: "APP_ENVIRONMENT", value: "production"))
    }

    func testInit_WhenURLHasNoHost_ShouldThrowInvalid() {
        // Arrange: a URL written with "//" in an .xcconfig loses everything after it.
        let info = ["APP_ENVIRONMENT": "debug", "API_BASE_URL": "https:"]

        // Act
        let error = configurationError(for: info)

        // Assert
        XCTAssertEqual(error, .invalid(key: "API_BASE_URL", value: "https:"))
    }

    func testInit_WhenReleaseUsesPlainHTTP_ShouldThrowInvalid() {
        // Arrange
        let info = ["APP_ENVIRONMENT": "release", "API_BASE_URL": "http://api.example.com"]

        // Act
        let error = configurationError(for: info)

        // Assert
        XCTAssertEqual(error, .invalid(key: "API_BASE_URL", value: "http://api.example.com"))
    }

    func testInit_WhenDebugUsesPlainHTTP_ShouldSucceed() throws {
        // Arrange
        let info = ["APP_ENVIRONMENT": "debug", "API_BASE_URL": "http://localhost:3000"]

        // Act
        let environment = try AppEnvironment(info: info)

        // Assert
        XCTAssertEqual(environment.apiBaseURL.port, 3000)
    }

    func testLoad_WhenRunningInTheAppBundle_ShouldSucceed() throws {
        // Act: the real Info.plist, filled from the active .xcconfig.
        let environment = try AppEnvironment.load()

        // Assert
        XCTAssertEqual(environment.kind, .debug)
        XCTAssertEqual(environment.apiBaseURL.scheme, "https")
    }

    private func configurationError(
        for info: [String: Any]
    ) -> AppEnvironment.ConfigurationError? {
        do {
            _ = try AppEnvironment(info: info)
            return nil
        } catch {
            return error
        }
    }
}
