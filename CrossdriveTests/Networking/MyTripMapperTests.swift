@testable import Crossdrive
import XCTest

final class MyTripMapperTests: XCTestCase {
    private let mapper = MyTripMapper()

    func testMap_WhenReplyIsComplete_ShouldKeepEveryField() throws {
        // Arrange
        let json = "[\(Self.behia)]"

        // Act
        let trip = try XCTUnwrap(mapper.trips(from: decode(json)).first)

        // Assert
        XCTAssertEqual(trip.id, "behia")
        XCTAssertEqual(trip.registrationID, "reg-1")
        XCTAssertEqual(trip.status, .going)
        XCTAssertEqual(trip.event.name, "Behia Mission Trip")
        XCTAssertEqual(trip.event.fee, Money(amountMinor: 150_000, currency: "PHP"))
        XCTAssertEqual(trip.meetup?.point, "Magallanes port")
        XCTAssertEqual(trip.lead, MyTrip.Lead(name: "Mark", phone: "09171234567"))
        XCTAssertEqual(trip.team, MyTrip.Team(id: "film", name: "Film crew"))
        XCTAssertEqual(trip.permit, MyTrip.Permit(name: "Maria Bañares", signed: false))
        XCTAssertEqual(trip.bring.map(\.title), ["Water bottle", "Hat and sunscreen", "Valid ID"])
        XCTAssertEqual(trip.packed, ["water"])
        XCTAssertEqual(trip.packedCount, 1)
        XCTAssertTrue(trip.remindNightBefore)
        XCTAssertEqual(trip.schedule?.published, true)
        XCTAssertEqual(trip.schedule?.items.first?.ask?.name, "Mark")
        XCTAssertNotNil(trip.schedule?.items.first?.movedFrom)
    }

    func testMap_WhenOptionalBlocksAreMissing_ShouldKeepTheTrip() throws {
        // Arrange
        let json = #"""
        [{"registration": {"id": "reg-2", "status": "pending"},
          "event": {"id": "camp", "kind": "camp", "name": "Young Missionaries Camp",
                    "startsAt": "2027-02-20T08:00:00+08:00", "endsAt": "2027-02-22T17:00:00+08:00"},
          "bring": []}]
        """#

        // Act
        let trip = try XCTUnwrap(mapper.trips(from: decode(json)).first)

        // Assert
        XCTAssertNil(trip.meetup)
        XCTAssertNil(trip.lead)
        XCTAssertNil(trip.schedule)
        XCTAssertNil(trip.event.fee)
        XCTAssertEqual(trip.bring, [])
        XCTAssertFalse(trip.remindNightBefore)
    }

    func testMap_WhenStatusIsUnknown_ShouldDropTheTrip() throws {
        // Arrange
        let json = "[\(Self.behia.replacingOccurrences(of: "\"going\"", with: "\"cancelled\""))]"

        // Act
        let trips = try mapper.trips(from: decode(json))

        // Assert
        XCTAssertEqual(trips, [])
    }

    func testToDos_WhenWaitlisted_ShouldBeEmpty() throws {
        // Arrange
        var trip = try XCTUnwrap(mapper.trips(from: decode("[\(Self.behia)]")).first)

        // Act
        trip.status = .waitlisted

        // Assert
        XCTAssertEqual(trip.toDos, [])
    }

    func testToDos_WhenUnpaidAndPermitWaiting_ShouldListFeeThenPermit() throws {
        // Arrange
        let trip = try XCTUnwrap(mapper.trips(from: decode("[\(Self.behia)]")).first)

        // Act
        let toDos = trip.toDos

        // Assert
        XCTAssertEqual(toDos, [
            .fee(Money(amountMinor: 150_000, currency: "PHP"), payBy: trip.event.payBy),
            .permit(name: "Maria Bañares"),
        ])
    }

    func testCountdown_WhenTripStartsNextManilaDay_ShouldSayTomorrow() throws {
        // Arrange: 11 PM in Manila the night before.
        let trip = try XCTUnwrap(mapper.trips(from: decode("[\(Self.behia)]")).first)
        let now = try Date("2026-12-11T23:00:00+08:00", strategy: .iso8601)

        // Act
        let text = trip.countdown(now: now)

        // Assert
        XCTAssertEqual(text, "The trip starts tomorrow")
    }

    func testCountdown_WhenTripIsToday_ShouldSayToday() throws {
        // Arrange: 4 AM in Manila on the day.
        let trip = try XCTUnwrap(mapper.trips(from: decode("[\(Self.behia)]")).first)
        let now = try Date("2026-12-12T04:00:00+08:00", strategy: .iso8601)

        // Act
        let text = trip.countdown(now: now)

        // Assert
        XCTAssertEqual(text, "The trip starts today")
    }

    private func decode(_ json: String) throws -> [MyTripDTO] {
        try JSONDecoder().decode([MyTripDTO].self, from: Data(json.utf8))
    }

    static let behia = #"""
    {"registration": {"id": "reg-1", "status": "going", "waiverSigned": true, "paid": false,
                      "permit": {"name": "Maria Bañares", "signed": false}},
     "event": {"id": "behia", "kind": "trip", "name": "Behia Mission Trip",
               "startsAt": "2026-12-12T05:30:00+08:00", "endsAt": "2026-12-14T18:00:00+08:00",
               "fee": {"amountMinor": 150000, "currency": "PHP"}, "payBy": "2026-12-12T00:00:00+08:00"},
     "meetup": {"point": "Magallanes port", "startsAt": "2026-12-12T05:30:00+08:00",
                "latitude": 12.83, "longitude": 123.83},
     "lead": {"name": "Mark", "phone": "09171234567"},
     "team": {"id": "film", "name": "Film crew"},
     "schedule": {"published": true, "updatedAt": "2026-12-12T06:10:00+08:00",
                  "items": [{"id": "boat", "startsAt": "2026-12-12T06:00:00+08:00",
                             "title": "Boat to Bagatao Island", "place": "Magallanes port",
                             "ask": {"name": "Mark"}, "movedFrom": "2026-12-12T05:45:00+08:00"}]},
     "bring": [{"id": "water", "title": "Water bottle"}, {"id": "hat", "title": "Hat and sunscreen"},
               {"id": "id", "title": "Valid ID"}],
     "packed": ["water"],
     "remindNightBefore": true}
    """#
}
