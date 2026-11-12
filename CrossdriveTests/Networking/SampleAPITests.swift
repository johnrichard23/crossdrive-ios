@testable import Crossdrive
import DataLayer
import XCTest

final class SampleAPITests: XCTestCase {
    func testItems_WhenAnItemHasNoID_ShouldSkipItAndKeepTheRest() async throws {
        // Arrange
        let client = StubHTTPClient { _ in
            .json(#"[{"id": "1", "title": "A"}, {"title": "No id"}]"#)
        }

        // Act
        let items = try await SampleAPI(client: client).items()

        // Assert
        XCTAssertEqual(items.map(\.id), ["1"])
    }

    func testItems_WhenCalled_ShouldGetTheItemsPath() async throws {
        // Arrange
        let client = StubHTTPClient { _ in .json("[]") }

        // Act
        _ = try await SampleAPI(client: client).items()

        // Assert
        XCTAssertEqual(client.requests.map(\.path), ["items"])
        XCTAssertEqual(client.requests.map(\.method), [.get])
    }

    func testSetFavorite_WhenCalled_ShouldPutTheFlagToTheItemPath() async throws {
        // Arrange
        let client = StubHTTPClient { _ in .json("{}") }

        // Act
        try await SampleAPI(client: client).setFavorite(true, forItem: "1")

        // Assert
        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.path, "items/1/favorite")
        let body = try JSONDecoder().decode([String: Bool].self, from: XCTUnwrap(request.body))
        XCTAssertEqual(body, ["isFavorite": true])
    }

    func testSetFavorite_WhenTheIDContainsASlash_ShouldNotAddPathSegments() async throws {
        // Arrange
        let client = StubHTTPClient { _ in .json("{}") }

        // Act
        try await SampleAPI(client: client).setFavorite(true, forItem: "a/b")

        // Assert
        XCTAssertEqual(client.requests.first?.path, "items/a%2Fb/favorite")
    }
}
