@testable import Crossdrive
import XCTest

final class ScheduleTimelineTests: XCTestCase {
    private typealias Item = MyTrip.ScheduleItem

    func testDays_WhenItemsSpanThreeDays_ShouldGroupInOrder() throws {
        // Arrange
        let schedule = try Self.schedule()

        // Act
        let days = ScheduleTimeline(schedule: schedule).days

        // Assert
        XCTAssertEqual(days.map(\.number), [1, 2, 3])
        XCTAssertEqual(
            days.map { $0.items.map(\.id) },
            [["kids", "film", "lunch"], ["clinic"], ["home"]]
        )
    }

    func testDayToOpen_WhenBeforeTheTrip_ShouldBeDayOne() throws {
        // Arrange
        let timeline = try ScheduleTimeline(schedule: Self.schedule())

        // Act
        let day = try timeline.dayToOpen(now: Self.date("2026-12-01T09:00:00+08:00"))

        // Assert
        XCTAssertEqual(day, timeline.days.first?.id)
    }

    func testDayToOpen_WhenDuringTheTrip_ShouldBeToday() throws {
        // Arrange
        let timeline = try ScheduleTimeline(schedule: Self.schedule())

        // Act
        let day = try timeline.dayToOpen(now: Self.date("2026-12-13T08:00:00+08:00"))

        // Assert
        XCTAssertEqual(day, timeline.days[1].id)
    }

    func testPhase_WhenAt930OnDayOne_ShouldMarkKidsCampNowAndFilmWorkshopNext() throws {
        // Arrange
        let schedule = try Self.schedule()
        let timeline = ScheduleTimeline(schedule: schedule)
        let now = try Self.date("2026-12-12T09:30:00+08:00")

        // Act
        let phases = schedule.items.map { timeline.phase(of: $0, now: now) }

        // Assert
        XCTAssertEqual(phases, [.now, .next, .later, .later, .later])
        XCTAssertEqual(timeline.upNext(now: now)?.id, "film")
    }

    func testNowAndNext_WhenDeviceIsInAnotherTimeZone_ShouldUseManilaTime() throws {
        // Arrange: 12:30 AM on Dec 13 in Manila is still Dec 12 in UTC.
        let original = NSTimeZone.default
        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "UTC"))
        defer { NSTimeZone.default = original }
        let timeline = try ScheduleTimeline(schedule: Self.schedule())

        // Act
        let day = try timeline.dayToOpen(now: Self.date("2026-12-13T00:30:00+08:00"))

        // Assert
        XCTAssertEqual(day, timeline.days[1].id)
    }

    private static func schedule() throws -> MyTrip.Schedule {
        try MyTrip.Schedule(published: true, updatedAt: nil, items: [
            item("kids", "2026-12-12T09:00:00+08:00", ends: "2026-12-12T10:30:00+08:00"),
            item("film", "2026-12-12T10:45:00+08:00", ends: "2026-12-12T12:00:00+08:00"),
            item("lunch", "2026-12-12T12:00:00+08:00"),
            item("clinic", "2026-12-13T09:00:00+08:00"),
            item("home", "2026-12-14T14:00:00+08:00"),
        ])
    }

    private static func item(_ id: String, _ starts: String, ends: String? = nil) throws -> Item {
        try Item(
            id: id,
            startsAt: date(starts),
            endsAt: ends.map(date),
            title: id,
            summary: nil,
            place: nil,
            latitude: nil,
            longitude: nil,
            team: nil,
            bring: nil,
            ask: nil,
            movedFrom: nil
        )
    }

    private static func date(_ text: String) throws -> Date {
        try Date(text, strategy: .iso8601)
    }
}
