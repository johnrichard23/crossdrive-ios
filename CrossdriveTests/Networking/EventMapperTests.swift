@testable import Crossdrive
import XCTest

final class EventMapperTests: XCTestCase {
    private let mapper = EventMapper()

    func testDetail_WhenPersonIsGuest_ShouldDropTheMeetup() throws {
        // Arrange
        let dto =
            try decode(#"{"event": \#(event), "meetup": {"point": "Port", "time": "5:30 AM"}}"#)

        // Act
        let detail = try XCTUnwrap(mapper.detail(from: dto))

        // Assert
        XCTAssertNil(detail.meetup)
        XCTAssertNil(detail.registration)
    }

    func testDetail_WhenPersonIsGoing_ShouldKeepTheMeetup() throws {
        // Arrange
        let json = #"""
        {"event": \#(event), "me": {"status": "going", "waiverSigned": true, "paid": false},
         "meetup": {"point": "Magallanes port", "time": "5:30 AM"}}
        """#

        // Act
        let detail = try XCTUnwrap(mapper.detail(from: decode(json)))

        // Assert
        XCTAssertEqual(detail.meetup, EventMeetup(point: "Magallanes port", time: "5:30 AM"))
        XCTAssertEqual(detail.bar, .going(paid: false, waiverSigned: true))
    }

    func testDetail_WhenPartsAreUnreadable_ShouldDropThemAndKeepTheRest() throws {
        // Arrange
        let json = #"""
        {"event": \#(event),
         "covers": [{"id": "a", "name": "Boat"}, {"name": "No id"}, {"id": "c", "name": ""}],
         "location": {"name": "Island", "latitude": 99, "longitude": 10},
         "me": {"status": "unknown"},
         "bringList": ["Bible", ""]}
        """#

        // Act
        let detail = try XCTUnwrap(mapper.detail(from: decode(json)))

        // Assert
        XCTAssertEqual(detail.covers.map(\.name), ["Boat"])
        XCTAssertNil(detail.location)
        XCTAssertNil(detail.registration)
        XCTAssertEqual(detail.bringList, ["Bible"])
    }

    func testModel_WhenStatusIsFull_ShouldMarkItFullAndClosed() throws {
        // Arrange
        let dto = try JSONDecoder().decode(
            EventDTO.self,
            from: Data(
                #"{"id": "e", "title": "T", "startsAt": "2026-12-11T22:00:00Z", "status": "full"}"#
                    .utf8
            )
        )

        // Act
        let model = try XCTUnwrap(mapper.model(from: dto))

        // Assert
        XCTAssertTrue(model.isFull)
        XCTAssertTrue(model.isClosed)
    }

    private let event = #"{"id": "e", "title": "T", "startsAt": "2026-12-11T22:00:00Z"}"#

    private func decode(_ json: String) throws -> EventDetailDTO {
        try JSONDecoder().decode(EventDetailDTO.self, from: Data(json.utf8))
    }
}
