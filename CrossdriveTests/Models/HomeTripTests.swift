@testable import Crossdrive
import XCTest

final class HomeTripTests: XCTestCase {
    func testCountdown_ForEachDay_ShouldCountManilaDays() {
        // Arrange: the trip starts Dec 12, 6 AM in Manila.
        let trip = homeTrip(registration: nil)
        let cases: [(now: String, expected: String?)] = [
            ("2026-11-25T16:00:00Z", "Starts in 16 days"),
            ("2026-12-10T16:30:00Z", "Starts tomorrow"),
            ("2026-12-11T16:30:00Z", "Starts today"),
            ("2026-12-12T16:30:00Z", nil),
        ]

        for item in cases {
            // Act
            let countdown = trip.countdown(now: date(item.now))

            // Assert
            XCTAssertEqual(countdown, item.expected, item.now)
        }
    }

    func testToDoCount_ForEachRegistration_ShouldCountUnpaidFeeAndUnsignedWaiver() {
        // Arrange
        let cases: [(registration: EventRegistration?, expected: Int)] = [
            (nil, 0),
            (EventRegistration(status: .waitlisted, waiverSigned: false, isPaid: false), 0),
            (EventRegistration(status: .going, waiverSigned: false, isPaid: false), 2),
            (EventRegistration(status: .going, waiverSigned: true, isPaid: false), 1),
            (EventRegistration(status: .going, waiverSigned: true, isPaid: true), 0),
        ]

        for item in cases {
            // Act
            let count = homeTrip(registration: item.registration).toDoCount

            // Assert
            XCTAssertEqual(count, item.expected)
        }
    }

    private func homeTrip(registration: EventRegistration?) -> HomeTrip {
        let event = Event(
            id: "e",
            kind: .trip,
            title: "Behia",
            place: nil,
            startsAt: date("2026-12-11T22:00:00Z"),
            endsAt: nil,
            travelTime: nil,
            fee: nil,
            capacity: nil,
            registeredCount: 0,
            isClosed: false,
            heroImageURL: nil
        )
        return HomeTrip(event: event, registration: registration)
    }

    private func date(_ text: String) -> Date {
        (try? Date(text, strategy: .iso8601)) ?? .distantPast
    }
}
