@testable import Crossdrive
import DataLayer
import XCTest

private let twoEventsJSON = """
[
  {"id": "camp", "kind": "camp", "title": "Camp", "startsAt": "2027-02-19T22:00:00Z"},
  {"id": "trip", "kind": "trip", "title": "Trip", "startsAt": "2026-12-11T22:00:00Z"},
  {"id": "bad", "title": "No date"}
]
"""

@MainActor
final class EventsViewModelTests: XCTestCase {
    func testLoad_WhenServerReturnsEvents_ShouldShowReadableOnesSoonestFirst() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json(twoEventsJSON) }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.visibleEvents.map(\.id), ["trip", "camp"])
    }

    func testVisibleEvents_WhenAKindChipIsOn_ShouldShowOnlyThatKind() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json(twoEventsJSON) }
        await viewModel.load()

        // Act
        viewModel.kind = .camp

        // Assert
        XCTAssertEqual(viewModel.visibleEvents.map(\.id), ["camp"])
    }

    func testLoad_WhenServerReturnsNothing_ShouldBeLoadedAndEmpty() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json("[]") }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .loaded([]))
    }

    func testLoad_WhenOffline_ShouldBeOffline() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in throw NetworkError.noConnection }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .offline)
    }

    func testLoad_WhenAlreadyLoaded_ShouldNotAskAgain() async {
        // Arrange
        let (viewModel, client) = makeViewModel { _ in .json(twoEventsJSON) }
        await viewModel.load()

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(client.requests.count, 1)
    }

    func testDetailViewModel_WhenAskedTwiceForTheSameTrip_ShouldReturnTheSameOne() {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json("[]") }

        // Act
        let first = viewModel.detailViewModel(for: "behia")
        let second = viewModel.detailViewModel(for: "behia")

        // Assert
        XCTAssertTrue(first === second)
    }

    func testOpenTripsChanged_WhenATripIsClosed_ShouldFreeItsViewModel() {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json("[]") }
        weak var weakDetail: EventDetailViewModel?
        autoreleasepool { weakDetail = viewModel.detailViewModel(for: "behia") }
        XCTAssertNotNil(weakDetail)

        // Act
        viewModel.openTripsChanged(to: [])

        // Assert
        XCTAssertNil(weakDetail)
    }

    private func makeViewModel(
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
    ) -> (EventsViewModel, StubHTTPClient) {
        let client = StubHTTPClient(handler)
        return (EventsViewModel(
            api: EventsAPI(client: client),
            imageLoader: FakeImageLoader(),
            snapshotter: FakeSnapshotter()
        ), client)
    }
}
