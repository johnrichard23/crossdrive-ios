@testable import Crossdrive
import DataLayer
import XCTest

final class MyTripsRepositoryTests: XCTestCase {
    func testAll_WhenOfflineAfterALoad_ShouldReturnTheSavedTrips() async throws {
        // Arrange: the first call reaches the server, the second has no signal.
        let calls = Counter()
        let client = StubHTTPClient { endpoint in
            guard calls.next() == 1 else { throw NetworkError.noConnection }
            return try await SampleStub.handle(endpoint)
        }
        let container = DependencyContainer.preview(client: client)
        _ = try await container.myTrips.all()

        // Act
        let trips = try await container.myTrips.all()

        // Assert
        XCTAssertEqual(trips.map(\.id), ["behia-going", "bulan", "camp-feb"])
    }

    func testSignOut_WhenTripsAreSaved_ShouldEmptyTheStore() async throws {
        // Arrange
        let container = DependencyContainer.preview()
        _ = try await container.myTrips.all()

        // Act
        await container.signOut()

        // Assert
        let saved = try await container.myTripsStore.all()
        XCTAssertEqual(saved.count, 0)
    }
}
