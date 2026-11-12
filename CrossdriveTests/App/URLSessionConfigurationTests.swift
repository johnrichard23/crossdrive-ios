@testable import Crossdrive
import XCTest

final class URLSessionConfigurationTests: XCTestCase {
    func testMakeURLSession_WhenCreated_ShouldWriteNothingToTheDiskCache() {
        // Act
        let configuration = DependencyContainer.makeURLSession().configuration

        // Assert
        XCTAssertNil(configuration.urlCache)
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testMakeURLSession_WhenCreated_ShouldNeitherKeepNorSendCookies() {
        // Act
        let configuration = DependencyContainer.makeURLSession().configuration

        // Assert
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertEqual(configuration.httpCookieAcceptPolicy, .never)
    }
}
