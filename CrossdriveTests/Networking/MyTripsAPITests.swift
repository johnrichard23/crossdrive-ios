@testable import Crossdrive
import DataLayer
import XCTest

final class MyTripsAPITests: XCTestCase {
    func testTrips_WhenStubAnswers_ShouldReturnThreeTripsSoonestFirst() async throws {
        // Arrange
        let api = MyTripsAPI(client: StubHTTPClient(SampleStub.handle))

        // Act
        let trips = try await api.trips()

        // Assert
        XCTAssertEqual(trips.map(\.id), ["behia-going", "bulan", "camp-feb"])
        XCTAssertEqual(trips.map(\.status), [.going, .waitlisted, .pending])
    }

    func testSetPacked_WhenCalled_ShouldPutToTheItemPathWithBody() async throws {
        // Arrange
        let client = StubHTTPClient { _ in .json("{}") }

        // Act
        try await MyTripsAPI(client: client).setPacked(true, item: "water", registration: "reg-1")

        // Assert
        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.path, "me/registrations/reg-1/packed/water")
        let body = try JSONDecoder().decode([String: Bool].self, from: XCTUnwrap(request.body))
        XCTAssertEqual(body, ["packed": true])
    }

    func testSetPacked_WhenIDHasASlash_ShouldEscapeIt() async throws {
        // Arrange
        let client = StubHTTPClient { _ in .json("{}") }

        // Act
        try await MyTripsAPI(client: client).setPacked(false, item: "a/b", registration: "r/1")

        // Assert
        XCTAssertEqual(client.requests.first?.path, "me/registrations/r%2F1/packed/a%2Fb")
    }

    func testSetReminder_WhenCalled_ShouldPutTheFlag() async throws {
        // Arrange
        let client = StubHTTPClient { _ in .json("{}") }

        // Act
        try await MyTripsAPI(client: client).setReminder(true, registration: "reg-1")

        // Assert
        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.path, "me/registrations/reg-1/reminder")
        let body = try JSONDecoder().decode([String: Bool].self, from: XCTUnwrap(request.body))
        XCTAssertEqual(body, ["on": true])
    }
}
