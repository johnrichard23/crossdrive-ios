@testable import Crossdrive
import XCTest

final class EventDetailTests: XCTestCase {
    func testBar_ForEachCase_ShouldFollowTheRules() {
        // Act and Assert
        XCTAssertEqual(detail().bar, .register)
        XCTAssertEqual(detail(full: true).bar, .full)
        XCTAssertEqual(detail(closed: true).bar, .closed)
        XCTAssertEqual(detail(status: .waitlisted, full: true).bar, .waitlisted)
        XCTAssertEqual(
            detail(status: .going, full: true).bar,
            .going(paid: false, waiverSigned: false)
        )
    }

    func testBar_WhenAllSlotsAreTakenButTheStatusIsOpen_ShouldOfferTheWaitlist() {
        // Act and Assert
        XCTAssertEqual(detail(capacity: 34, registered: 34).bar, .full)
        XCTAssertEqual(detail(capacity: 34, registered: 22).bar, .register)
    }

    func testBar_WhenSignUpIsClosedButSlotsRemain_ShouldBeClosedNotFull() {
        // Act and Assert
        XCTAssertEqual(detail(capacity: 34, registered: 22, closed: true).bar, .closed)
        XCTAssertEqual(detail(capacity: 34, registered: 34, closed: true).bar, .closed)
    }

    func testBandStats_WhenSignUpIsClosedButSlotsRemain_ShouldShowTheSlotsLeft() {
        // Act
        let slots = detail(capacity: 34, registered: 22, closed: true).bandStats.last

        // Assert
        XCTAssertEqual(slots, EventBandStat(value: "12", label: "slots left"))
    }

    func testBandStats_WhenFull_ShouldSayFull() {
        // Act and Assert
        XCTAssertEqual(
            detail(capacity: 34, registered: 34).bandStats.last,
            EventBandStat(value: "Full", label: "no slots left")
        )
        XCTAssertEqual(
            detail(capacity: 34, registered: 10, full: true).bandStats.last,
            EventBandStat(value: "Full", label: "no slots left")
        )
    }

    func testCoversFitGrid_ForEachCount_ShouldUseAGridForTwoToFour() {
        // Act and Assert
        XCTAssertFalse(detail(covers: 0).coversFitGrid)
        XCTAssertFalse(detail(covers: 1).coversFitGrid)
        XCTAssertTrue(detail(covers: 2).coversFitGrid)
        XCTAssertTrue(detail(covers: 4).coversFitGrid)
        XCTAssertFalse(detail(covers: 5).coversFitGrid)
    }

    func testPeopleLabel_ForEachCase_ShouldGroupThousands() {
        // Act and Assert
        XCTAssertEqual(detail(people: 1200).peopleLabel, "1,200")
        XCTAssertEqual(detail(people: 800).peopleLabel, "800")
        XCTAssertNil(detail().peopleLabel)
    }

    func testCaption_WhenAreaIsMissing_ShouldShowOnlyTheName() {
        // Act and Assert
        XCTAssertEqual(
            EventLocation(name: "Bagatao Island", area: "Magallanes", latitude: 1, longitude: 2)
                .caption,
            "Bagatao Island, Magallanes"
        )
        XCTAssertEqual(
            EventLocation(name: "Bulan", area: nil, latitude: 1, longitude: 2).caption,
            "Bulan"
        )
    }

    func testMapsURL_Always_ShouldBeAnHTTPSLinkWithThePoint() {
        // Arrange
        let location = EventLocation(name: "Bulan", area: nil, latitude: 12.5, longitude: 123.5)

        // Act
        let url = location.mapsURL

        // Assert
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertTrue(url?.absoluteString.contains("ll=12.5,123.5") ?? false)
    }

    private func detail(
        status: EventRegistration.Status? = nil,
        capacity: Int? = nil,
        registered: Int = 0,
        full: Bool = false,
        closed: Bool = false,
        covers: Int = 0,
        people: Int? = nil
    ) -> EventDetail {
        EventDetail(
            event: Event(
                id: "e", kind: .trip, title: "Behia", place: nil,
                startsAt: .distantFuture, endsAt: nil, travelTime: nil, fee: nil,
                capacity: capacity, registeredCount: registered, isClosed: closed || full,
                isFull: full,
                heroImageURL: nil
            ),
            summary: "", background: "", photoURLs: [], roles: [], peopleCount: people,
            location: nil,
            covers: (0 ..< covers).map { EventCover(id: "\($0)", name: "Item", iconKey: nil) },
            notCovered: nil, bringList: [],
            registration: status.map {
                EventRegistration(status: $0, waiverSigned: false, isPaid: false)
            },
            meetup: nil
        )
    }
}
