@testable import Crossdrive
import XCTest

final class DeepLinkRouterTests: XCTestCase {
    private let router = DeepLinkRouter(scheme: "myapp", universalLinkHosts: ["links.example.com"])

    // MARK: - The app's own scheme

    func testParse_WhenItIsAnItemLink_ShouldReturnTheItem() {
        // Act
        let link = router.parse(url("myapp://items/42"))

        // Assert
        XCTAssertEqual(link, .item("42"))
    }

    func testParse_WhenTheSchemeIsUpperCase_ShouldStillMatch() {
        // Act
        let link = router.parse(url("MyApp://items/42"))

        // Assert
        XCTAssertEqual(link, .item("42"))
    }

    func testParse_WhenTheLinkHasAQueryAndFragment_ShouldIgnoreThem() {
        // Act
        let link = router.parse(url("myapp://items/42?utm_source=mail#top"))

        // Assert
        XCTAssertEqual(link, .item("42"))
    }

    func testParse_WhenTheIDIsPercentEncoded_ShouldDecodeIt() {
        // Act
        let link = router.parse(url("myapp://items/a%20b"))

        // Assert
        XCTAssertEqual(link, .item("a b"))
    }

    func testParse_WhenAnotherAppsSchemeIsUsed_ShouldReturnNil() {
        // Act and Assert
        XCTAssertNil(router.parse(url("otherapp://items/42")))
    }

    func testParse_WhenThePathIsUnknown_ShouldReturnNil() {
        // Act and Assert
        XCTAssertNil(router.parse(url("myapp://settings/42")))
        XCTAssertNil(router.parse(url("myapp://items")))
    }

    func testParse_WhenThereAreExtraSegments_ShouldReturnNil() {
        // Act and Assert
        XCTAssertNil(router.parse(url("myapp://items/42/reviews")))
    }

    func testParse_WhenTheIDIsTooLong_ShouldReturnNil() {
        // Arrange
        let longID = String(repeating: "a", count: 201)

        // Act and Assert
        XCTAssertNil(router.parse(url("myapp://items/\(longID)")))
    }

    func testParse_WhenTheIDHasAControlCharacter_ShouldReturnNil() {
        // Act and Assert
        XCTAssertNil(router.parse(url("myapp://items/a%00b")))
    }

    func testParse_WhenAnEmptySchemeIsConfigured_ShouldMatchNothing() {
        // Arrange: an app whose Info.plist registers no scheme.
        let router = DeepLinkRouter(scheme: "")

        // Act and Assert
        XCTAssertNil(router.parse(url("://items/42")))
    }

    // MARK: - Universal links

    func testParse_WhenAListedHostIsUsed_ShouldReturnTheItem() {
        // Act
        let link = router.parse(url("https://links.example.com/items/42"))

        // Assert
        XCTAssertEqual(link, .item("42"))
    }

    func testParse_WhenTheHostIsNotListed_ShouldReturnNil() {
        // Act and Assert
        XCTAssertNil(router.parse(url("https://evil.example.org/items/42")))
    }

    func testParse_WhenNoHostsAreListed_ShouldIgnoreEveryWebLink() {
        // Arrange
        let router = DeepLinkRouter(scheme: "myapp")

        // Act and Assert
        XCTAssertNil(router.parse(url("https://links.example.com/items/42")))
    }

    func testParse_WhenAListedHostUsesPlainHTTP_ShouldReturnNil() {
        // Act and Assert
        XCTAssertNil(router.parse(url("http://links.example.com/items/42")))
    }

    // MARK: - From text

    func testParse_WhenTextIsALink_ShouldReturnTheItem() {
        // Act and Assert
        XCTAssertEqual(router.parse("myapp://items/7"), .item("7"))
    }

    func testParse_WhenTextIsNotAURL_ShouldReturnNil() {
        // Act and Assert
        XCTAssertNil(router.parse("not a url at all"))
        XCTAssertNil(router.parse(""))
    }

    // MARK: - The registered scheme

    func testInitFromBundle_WhenRunningInTheApp_ShouldReadTheSchemeInfoPlistRegisters() {
        // Act
        let router = DeepLinkRouter(bundle: .main)

        // Assert: the one place the scheme is written is the .xcconfig.
        XCTAssertFalse(router.scheme.isEmpty)
        XCTAssertEqual(router.parse(url("\(router.scheme)://items/1")), .item("1"))
    }

    private func url(_ text: String) -> URL {
        URL(string: text) ?? URL(fileURLWithPath: "/invalid")
    }
}
