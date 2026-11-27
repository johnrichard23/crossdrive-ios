@testable import Crossdrive
import DataLayer
import XCTest

@MainActor
final class MyTripLabelsTests: XCTestCase {
    func testMeetLine_WhenDeviceIsInUTC_ShouldStillUseManilaTime() async throws {
        // Arrange
        let original = NSTimeZone.default
        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "UTC"))
        defer { NSTimeZone.default = original }
        let trip = try await behia()

        // Act
        // iOS puts a narrow no-break space before "AM".
        let line = trip.meetLine?.replacingOccurrences(of: "\u{202F}", with: " ")

        // Assert
        XCTAssertEqual(line, "Meet Sat, Dec 12 · 5:30 AM, Magallanes port")
    }

    func testFeeLineAndToDos_WhenUnpaid_ShouldSayNotPaidAndTheDueDate() async throws {
        // Arrange
        let trip = try await behia()

        // Act
        let fee = trip.feeLine
        let firstToDo = try XCTUnwrap(trip.toDos.first)

        // Assert
        XCTAssertEqual(fee, "₱1,500 · not paid yet")
        XCTAssertEqual(firstToDo.detail, "₱1,500, before Dec 12")
    }

    func testBannerDetail_WhenFeeAndPermitAreOpen_ShouldJoinThemInOneLine() async throws {
        // Arrange
        let trip = try await behia()

        // Act
        let detail = MyTripView.bannerDetail(trip.toDos)

        // Assert
        XCTAssertEqual(detail, "Trip fee and guardian permit")
        XCTAssertEqual(MyTripView.bannerTitle(count: 2), "2 things to do before you go")
    }

    private func behia() async throws -> MyTrip {
        let trips = try await MyTripsAPI(client: StubHTTPClient(SampleStub.handle)).trips()
        return try XCTUnwrap(trips.first { $0.id == "behia-going" })
    }
}
