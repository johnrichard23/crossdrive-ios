@testable import Crossdrive
import DataLayer
import XCTest

@MainActor
final class MyTripViewModelTests: XCTestCase {
    func testLoad_WhenGoing_ShouldShowTheTripAndItsToDos() async throws {
        // Arrange
        let viewModel = makeViewModel(tripID: "behia-going")

        // Act
        await viewModel.load()

        // Assert
        let trip = try XCTUnwrap(viewModel.state.value)
        XCTAssertEqual(trip.event.name, "Behia Mission Trip")
        XCTAssertEqual(trip.toDos.count, 2)
    }

    func testLoad_WhenOfflineWithASavedTrip_ShouldShowIt() async throws {
        // Arrange: the trip loaded once, then the signal is gone.
        let calls = Counter()
        let client = StubHTTPClient { endpoint in
            guard calls.next() == 1 else { throw NetworkError.noConnection }
            return try await SampleStub.handle(endpoint)
        }
        let container = DependencyContainer.preview(client: client)
        _ = try await container.myTrips.all()
        let viewModel = MyTripViewModel(tripID: "behia-going", repository: container.myTrips)

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state.value?.id, "behia-going")
    }

    func testLoad_WhenOfflineWithNothingSaved_ShouldShowOffline() async {
        // Arrange
        let viewModel = makeViewModel(
            tripID: "behia-going",
            client: StubHTTPClient { _ in throw NetworkError.noConnection }
        )

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .offline)
    }

    func testUpNext_WhenPending_ShouldBeNil() async {
        // Arrange: the camp registration still waits for a coordinator.
        let viewModel = makeViewModel(tripID: "camp-feb")

        // Act
        await viewModel.load()

        // Assert
        XCTAssertNil(viewModel.upNext)
    }

    func testUpNext_WhenGoingTheDayBefore_ShouldBeTheBoat() async throws {
        // Arrange
        let now = try Date("2026-12-11T20:00:00+08:00", strategy: .iso8601)
        let viewModel = makeViewModel(tripID: "behia-going", now: now)

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.upNext?.title, "Boat to Bagatao Island")
    }

    private func makeViewModel(
        tripID: Event.ID,
        client: StubHTTPClient = StubHTTPClient(SampleStub.handle),
        now: Date = Date(timeIntervalSince1970: 1_790_000_000)
    ) -> MyTripViewModel {
        let container = DependencyContainer.preview(client: client)
        return MyTripViewModel(tripID: tripID, repository: container.myTrips, now: { now })
    }
}
