@testable import Crossdrive
import XCTest

final class HomeTripTests: XCTestCase {
    private func trip(
        startsAt: String,
        endsAt: String = "2026-12-14T10:00:00Z"
    ) throws -> HomeTrip {
        let json = SampleStub.homeJSON()
            .replacingOccurrences(of: "2026-12-11T22:00:00Z", with: startsAt)
            .replacingOccurrences(of: "2026-12-14T10:00:00Z", with: endsAt)
        let dto = try JSONDecoder().decode(HomeDTO.self, from: Data(json.utf8))
        return try XCTUnwrap(HomeMapper().model(from: dto).trip)
    }

    private func date(_ iso: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: iso))
    }

    func testCountdown_WhenTripIsDaysAway_ShouldCountWholeDaysInManila() throws {
        // Arrange: starts Dec 12 06:00 Manila; now is Dec 9 23:30 Manila (Dec 9 15:30Z).
        let trip = try trip(startsAt: "2026-12-11T22:00:00Z")

        // Act
        let countdown = try trip.countdown(now: date("2026-12-09T15:30:00Z"))

        // Assert
        XCTAssertEqual(countdown?.number, "3")
        XCTAssertEqual(countdown?.caption, "days until the Behia Mission Trip")
    }

    func testCountdown_WhenTripIsTomorrow_ShouldSayOneDay() throws {
        // Act
        let countdown = try trip(startsAt: "2026-12-11T22:00:00Z")
            .countdown(now: date("2026-12-11T01:00:00Z"))

        // Assert
        XCTAssertEqual(countdown?.number, "1")
        XCTAssertEqual(countdown?.caption, "day until the Behia Mission Trip")
    }

    func testCountdown_WhenTripStartsToday_ShouldSayToday() throws {
        // Act
        let countdown = try trip(startsAt: "2026-12-11T22:00:00Z")
            .countdown(now: date("2026-12-11T23:00:00Z").addingTimeInterval(-3 * 3600))

        // Assert
        XCTAssertEqual(countdown?.number, "Today")
    }

    func testCountdown_WhenTripIsOn_ShouldSayNow() throws {
        // Act
        let countdown = try trip(startsAt: "2026-12-11T22:00:00Z")
            .countdown(now: date("2026-12-13T02:00:00Z"))

        // Assert
        XCTAssertEqual(countdown?.number, "Now")
    }

    func testCountdown_WhenTripIsOver_ShouldBeNil() throws {
        // Act
        let countdown = try trip(startsAt: "2026-12-11T22:00:00Z")
            .countdown(now: date("2026-12-20T00:00:00Z"))

        // Assert
        XCTAssertNil(countdown)
    }
}
