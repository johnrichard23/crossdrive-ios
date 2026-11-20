@testable import Crossdrive
import DataLayer
import UIKit
import XCTest

final class HTTPImageLoaderTests: XCTestCase {
    private static let photoURL = url("https://example.com/a.jpg")
    private static let cdnURL = url("https://cdn.example.com/p/a.jpg")

    private static func url(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: "/")
    }

    func testImage_WhenTheServerSendsAPhoto_ShouldDecodeItAtTheRequestedSize() async throws {
        // Arrange
        let loader = HTTPImageLoader(client: StubHTTPClient { _ in
            HTTPResponse(status: 200, data: Self.jpeg(side: 800))
        })

        // Act
        let image = try await loader.image(
            for: XCTUnwrap(URL(string: "https://example.com/a.jpg")),
            maxPixels: 200
        )

        // Assert
        let decoded = try XCTUnwrap(image)
        XCTAssertLessThanOrEqual(decoded.size.width * decoded.scale, 200)
    }

    func testImage_WhenAskedTwice_ShouldDownloadOnce() async throws {
        // Arrange
        let client = StubHTTPClient { _ in HTTPResponse(status: 200, data: Self.jpeg(side: 400)) }
        let loader = HTTPImageLoader(client: client)
        let url = try XCTUnwrap(URL(string: "https://example.com/a.jpg"))

        // Act
        _ = await loader.image(for: url, maxPixels: 200)
        _ = await loader.image(for: url, maxPixels: 200)

        // Assert
        XCTAssertEqual(client.requests.count, 1)
    }

    func testImage_WhenTheReplyIsNotAPhoto_ShouldBeNil() async throws {
        // Arrange
        let loader = HTTPImageLoader(client: StubHTTPClient { _ in .json("{}") })

        // Act
        let image = try await loader.image(
            for: XCTUnwrap(URL(string: "https://example.com/a.jpg")),
            maxPixels: 200
        )

        // Assert
        XCTAssertNil(image)
    }

    func testImage_WhenTheRequestFails_ShouldBeNil() async throws {
        // Arrange
        let loader = HTTPImageLoader(client: StubHTTPClient { _ in
            throw NetworkError.noConnection
        })

        // Act
        let image = try await loader.image(
            for: XCTUnwrap(URL(string: "https://example.com/a.jpg")),
            maxPixels: 200
        )

        // Assert
        XCTAssertNil(image)
    }

    func testImage_Always_ShouldAskForAnImageAndUseTheFullAddress() async throws {
        // Arrange
        let client = StubHTTPClient { _ in HTTPResponse(status: 200, data: Self.jpeg(side: 100)) }
        let loader = HTTPImageLoader(client: client)

        // Act
        _ = try await loader.image(
            for: XCTUnwrap(URL(string: "https://cdn.example.com/p/a.jpg")),
            maxPixels: 100
        )

        // Assert
        XCTAssertEqual(client.requests.first?.path, Self.cdnURL.absoluteString)
        XCTAssertEqual(client.requests.first?.headers["Accept"], "image/*")
    }

    func testLoader_WhenItIsFreed_ShouldNotBeKeptAlive() async throws {
        // Arrange
        weak var weakLoader: HTTPImageLoader?
        do {
            let loader = HTTPImageLoader(client: StubHTTPClient { _ in
                HTTPResponse(status: 200, data: Self.jpeg(side: 100))
            })
            _ = try await loader.image(
                for: XCTUnwrap(URL(string: "https://example.com/a.jpg")),
                maxPixels: 100
            )
            weakLoader = loader
        }

        // Assert
        XCTAssertNil(weakLoader)
    }

    private static func jpeg(side: CGFloat) -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
            .image { context in
                UIColor.purple.setFill()
                context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
