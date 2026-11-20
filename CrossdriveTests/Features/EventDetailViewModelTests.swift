@testable import Crossdrive
import DataLayer
import XCTest

private let detailJSON = """
{
  "event": {"id": "e1", "title": "Behia", "startsAt": "2026-12-11T22:00:00Z"},
  "summary": "A weekend.",
  "photos": ["https://example.com/a.jpg"],
  "roles": [{"id": "r1", "name": "Cooking"}, {"name": "No id"}]
}
"""

@MainActor
final class EventDetailViewModelTests: XCTestCase {
    func testLoad_WhenServerReturnsTheEvent_ShouldBeLoadedWithItsReadableRoles() async {
        // Arrange
        let viewModel = makeViewModel { _ in .json(detailJSON) }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state.value?.event.id, "e1")
        XCTAssertEqual(viewModel.state.value?.roles.map(\.id), ["r1"])
    }

    func testLoad_WhenTheEventIsNotFound_ShouldBeUnavailable() async {
        // Arrange
        let viewModel = makeViewModel { _ in .json("{}", status: 404) }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertTrue(viewModel.isUnavailable)
    }

    func testLoad_WhenTheReplyHasNoReadableEvent_ShouldBeUnavailable() async {
        // Arrange
        let viewModel = makeViewModel { _ in .json("{}") }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertTrue(viewModel.isUnavailable)
    }

    func testLoad_WhenOffline_ShouldBeOfflineAndNotUnavailable() async {
        // Arrange
        let viewModel = makeViewModel { _ in throw NetworkError.noConnection }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .offline)
        XCTAssertFalse(viewModel.isUnavailable)
    }

    private func makeViewModel(
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
    ) -> EventDetailViewModel {
        EventDetailViewModel(
            api: EventsAPI(client: StubHTTPClient(handler)),
            eventID: "e1",
            imageLoader: FakeImageLoader(),
            snapshotter: FakeSnapshotter()
        )
    }
}
