@testable import Crossdrive
import XCTest

final class EventTests: XCTestCase {
    func testDateRangeLabel_ForEachCase_ShouldReadInManilaTime() {
        // Arrange: 2026-12-11 22:00 UTC is Dec 12, 6 AM in Manila.
        let cases = [
            DateCase(
                start: "2026-12-11T22:00:00Z",
                end: "2026-12-14T10:00:00Z",
                expected: "Dec 12 to 14"
            ),
            DateCase(
                start: "2026-12-29T22:00:00Z",
                end: "2027-01-02T04:00:00Z",
                expected: "Dec 30 to Jan 2"
            ),
            DateCase(
                start: "2026-12-11T22:00:00Z",
                end: "2026-12-12T06:00:00Z",
                expected: "Dec 12"
            ),
            DateCase(start: "2026-12-11T22:00:00Z", end: nil, expected: "Dec 12"),
        ]

        for item in cases {
            // Act
            let label = event(start: item.start, end: item.end).dateRangeLabel

            // Assert
            XCTAssertEqual(label, item.expected)
        }
    }

    func testStartDateParts_WhenUtcIsStillTheDayBefore_ShouldReadInManilaTime() {
        // Arrange: 2026-12-11 22:00 UTC is Dec 12, 6 AM in Manila.
        let event = event(start: "2026-12-11T22:00:00Z", end: nil)

        // Act and Assert
        XCTAssertEqual(event.startDayNumber, "12")
        XCTAssertEqual(event.startMonthAbbreviation, "Dec")
        XCTAssertEqual(event.startMonthName, "December")
    }

    func testSlotsLabel_ForEachCase_ShouldSayHowManyAreLeft() {
        // Arrange
        let cases = [
            SlotsCase(capacity: 40, registered: 28, closed: false, expected: "12 slots left"),
            SlotsCase(capacity: 40, registered: 39, closed: false, expected: "1 slot left"),
            SlotsCase(capacity: 40, registered: 40, closed: false, expected: "Full"),
            SlotsCase(capacity: 40, registered: 12, closed: true, expected: "Full"),
            SlotsCase(capacity: nil, registered: 0, closed: false, expected: nil),
            SlotsCase(capacity: nil, registered: 0, closed: true, expected: "Full"),
        ]

        for item in cases {
            // Act
            let label = event(
                capacity: item.capacity,
                registered: item.registered,
                closed: item.closed
            )
            .slotsLabel

            // Assert
            XCTAssertEqual(label, item.expected)
        }
    }

    func testFeeLabel_ForEachCase_ShouldNameTheCostPerPerson() {
        // Arrange
        let fee = Money(amountMinor: 150_000, currency: "PHP")

        // Act and Assert
        XCTAssertEqual(event(fee: fee).feeLabel, "₱1,500 per person")
        XCTAssertNil(event().feeLabel)
    }

    func testPlaceLine_ForEachCase_ShouldJoinWhatTheTripHas() {
        // Act and Assert
        XCTAssertEqual(
            event(place: "Bagatao Island", travel: "1 hr by boat").placeLine,
            "Bagatao Island · 1 hr by boat"
        )
        XCTAssertEqual(event(place: "Bulan, Sorsogon").placeLine, "Bulan, Sorsogon")
        XCTAssertEqual(event(travel: "2 hr by van").placeLine, "2 hr by van")
        XCTAssertNil(event().placeLine)
    }

    func testTravelParts_ForEachCase_ShouldSplitTheValueFromTheMode() {
        // Act
        let boat = event(travel: "1 hr by boat").travelParts
        let plain = event(travel: "About an hour").travelParts

        // Assert
        XCTAssertEqual(boat?.value, "1 hr")
        XCTAssertEqual(boat?.label, "by boat")
        XCTAssertEqual(plain?.value, "About an hour")
        XCTAssertEqual(plain?.label, "travel")
        XCTAssertNil(event().travelParts)
    }

    func testDaysAndNights_ForEachCase_ShouldUseDigits() {
        // Act and Assert
        XCTAssertEqual(
            event(start: "2026-12-11T22:00:00Z", end: "2026-12-14T10:00:00Z").daysAndNights,
            "3 days, 2 nights"
        )
        XCTAssertEqual(
            event(start: "2026-12-11T22:00:00Z", end: "2026-12-13T10:00:00Z").daysAndNights,
            "2 days, 1 night"
        )
        XCTAssertEqual(
            event(start: "2026-12-11T22:00:00Z", end: "2026-12-12T06:00:00Z").daysAndNights,
            "One day"
        )
        XCTAssertNil(event().daysAndNights)
    }

    func testPrayedLabel_ForEachCount_ShouldUseTheRightWords() {
        // Act and Assert
        XCTAssertNil(HomePrayer(id: "p", body: "", prayedCount: 0).prayedLabel)
        XCTAssertEqual(HomePrayer(id: "p", body: "", prayedCount: 1).prayedLabel, "1 person prayed")
        XCTAssertEqual(
            HomePrayer(id: "p", body: "", prayedCount: 47).prayedLabel,
            "47 people prayed"
        )
    }

    func testMoneyFormatted_WhenCentavosArePresent_ShouldShowThem() {
        // Act and Assert
        XCTAssertEqual(Money(amountMinor: 150_050, currency: "PHP").formatted, "₱1,500.50")
        XCTAssertEqual(Money(amountMinor: 0, currency: "PHP").formatted, "₱0")
    }

    func testSlotsTakenLabel_WhenThereIsALimit_ShouldSayHowManyAreTaken() {
        // Act and Assert
        XCTAssertEqual(
            event(capacity: 34, registered: 22).slotsTakenLabel,
            "22 of 34 slots taken"
        )
        XCTAssertNil(event().slotsTakenLabel)
        XCTAssertEqual(event(capacity: 40, registered: 10).takenFraction, 0.25)
    }

    private struct DateCase {
        let start: String
        let end: String?
        let expected: String
    }

    private struct SlotsCase {
        let capacity: Int?
        let registered: Int
        let closed: Bool
        let expected: String?
    }

    private func date(_ string: String) -> Date {
        (try? Date(string, strategy: .iso8601)) ?? .distantPast
    }

    private func event(
        start: String = "2026-12-11T22:00:00Z",
        end: String? = nil,
        capacity: Int? = nil,
        registered: Int = 0,
        closed: Bool = false,
        fee: Money? = nil,
        place: String? = nil,
        travel: String? = nil,
        title: String = "Behia"
    ) -> Event {
        Event(
            id: "e",
            kind: .trip,
            title: title,
            place: place,
            startsAt: date(start),
            endsAt: end.map(date),
            travelTime: travel,
            fee: fee,
            capacity: capacity,
            registeredCount: registered,
            isClosed: closed,
            heroImageURL: nil
        )
    }
}
