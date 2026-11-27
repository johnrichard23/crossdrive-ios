@testable import Crossdrive
import DataLayer
import XCTest

final class ProfileSummaryTests: XCTestCase {
    func testInitials_ForEachName_ShouldTakeTheFirstAndLastWords() {
        // Arrange
        let cases: [(name: String?, expected: String)] = [
            ("Joy Bañares", "JB"),
            ("Joy", "J"),
            ("  maria de la cruz ", "MC"),
            (nil, ""),
            ("   ", ""),
        ]

        for item in cases {
            // Act
            let summary = ProfileSummary(
                user: AppUser(id: "u", name: item.name),
                trips: [],
                now: .now
            )

            // Assert
            XCTAssertEqual(summary.initials, item.expected, item.name ?? "nil")
        }
    }

    func testTripsLine_ForEachCount_ShouldCountTheTrips() async throws {
        // Arrange
        let trips = try await stubTrips()
        let cases: [(count: Int, expected: String)] = [
            (0, "No trips yet"),
            (1, "1 trip"),
            (3, "3 trips"),
        ]

        for item in cases {
            // Act
            let summary = ProfileSummary(
                user: joy,
                trips: Array(trips.prefix(item.count)),
                now: .now
            )

            // Assert
            XCTAssertEqual(summary.tripsLine, item.expected)
        }
    }

    func testTrips_WhenSomeHaveEnded_ShouldPutComingTripsFirstSoonestFirst() async throws {
        // Arrange: on Jan 1, Behia (Dec) has ended; Bulan (Jan) and the camp (Feb) are coming.
        let now = try Date("2027-01-01T08:00:00+08:00", strategy: .iso8601)
        let trips = try await stubTrips()

        // Act
        let summary = ProfileSummary(user: joy, trips: trips, now: now)

        // Assert
        XCTAssertEqual(summary.trips.map(\.id), ["bulan", "camp-feb", "behia-going"])
        XCTAssertFalse(summary.hasMoreTrips)
    }

    func testTrips_WhenMoreThanThree_ShouldShowThreeAndSayThereAreMore() async throws {
        // Arrange: a fourth trip, later than the others.
        let stub = try await stubTrips()
        var later = try XCTUnwrap(stub.first)
        later.event.startsAt = try Date("2027-06-01T08:00:00+08:00", strategy: .iso8601)
        later.event.endsAt = try Date("2027-06-03T08:00:00+08:00", strategy: .iso8601)
        let trips = stub + [later]
        let now = try Date("2026-11-27T08:00:00+08:00", strategy: .iso8601)

        // Act
        let summary = ProfileSummary(user: joy, trips: trips, now: now)

        // Assert
        XCTAssertEqual(summary.trips.count, 3)
        XCTAssertTrue(summary.hasMoreTrips)
        XCTAssertEqual(summary.tripsLine, "4 trips")
    }

    private let joy = AppUser(id: "u", name: "Joy Bañares")

    private func stubTrips() async throws -> [MyTrip] {
        try await MyTripsAPI(client: StubHTTPClient(SampleStub.handle)).trips()
    }
}
