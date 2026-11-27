@testable import Crossdrive
import DataLayer
import XCTest

@MainActor
final class MyTripsViewModelTests: XCTestCase {
    func testLoad_WhenTripsReturn_ShouldSortSoonestFirstAndDropEnded() async throws {
        // Arrange: Jan 1 2027, after Behia ended.
        let now = try Date("2027-01-01T09:00:00+08:00", strategy: .iso8601)
        let viewModel = makeViewModel(now: now)

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state.value?.map(\.id), ["bulan", "camp-feb"])
    }

    func testStatus_WhenTheEventIsJoined_ShouldGiveItsStatus() async {
        // Arrange
        let viewModel = makeViewModel(now: Date(timeIntervalSince1970: 1_790_000_000))
        await viewModel.load()

        // Act
        let statuses = ["behia-going", "bulan", "camp-feb", "not-joined"].map(viewModel.status(of:))

        // Assert
        XCTAssertEqual(statuses, [.going, .waitlisted, .pending, nil])
    }

    func testLoad_WhenSignedOutWhileLoading_ShouldNotShowTheOldTrips() async {
        // Arrange: the first load waits for the server; the person signs out meanwhile.
        let started = Gate()
        let release = Gate()
        let client = StubHTTPClient { endpoint in
            await started.open()
            await release.wait()
            return try await SampleStub.handle(endpoint)
        }
        var signedIn = true
        let container = DependencyContainer.preview(client: client)
        let viewModel = MyTripsViewModel(repository: container.myTrips, isSignedIn: { signedIn })
        let first = Task { await viewModel.load() }
        await started.wait()

        // Act
        signedIn = false
        await viewModel.load(forceReload: true)
        await release.open()
        await first.value

        // Assert
        XCTAssertEqual(viewModel.state.value?.count, 0)
    }

    func testLoad_WhenGuest_ShouldNotCallTheServer() async {
        // Arrange
        let client = StubHTTPClient(SampleStub.handle)
        let viewModel = makeViewModel(client: client, isSignedIn: false)

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(client.requests.count, 0)
        XCTAssertEqual(viewModel.state.value?.count, 0)
    }

    func testLoad_WhenOfflineWithNothingSaved_ShouldShowOffline() async {
        // Arrange
        let client = StubHTTPClient { _ in throw NetworkError.noConnection }
        let viewModel = makeViewModel(client: client)

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .offline)
    }

    private func makeViewModel(
        client: StubHTTPClient = StubHTTPClient(SampleStub.handle),
        isSignedIn: Bool = true,
        now: Date = Date(timeIntervalSince1970: 1_790_000_000)
    ) -> MyTripsViewModel {
        let container = DependencyContainer.preview(client: client)
        return MyTripsViewModel(
            repository: container.myTrips,
            isSignedIn: { isSignedIn },
            now: { now }
        )
    }
}
