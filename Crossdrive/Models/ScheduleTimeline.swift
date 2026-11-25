import Foundation

/// A trip's schedule laid out by day, with what is on now and what is next.
/// Worked out on the phone from the clock, so it stays right offline.
struct ScheduleTimeline: Sendable {
    struct Day: Identifiable, Hashable, Sendable {
        /// The start of the day where the trip is.
        let id: Date
        /// Day 1, Day 2...
        let number: Int
        let items: [MyTrip.ScheduleItem]
    }

    enum Phase: Equatable, Sendable {
        case past
        case now
        case next
        case later
    }

    let days: [Day]
    private let items: [MyTrip.ScheduleItem]
    private let calendar: Calendar

    init(schedule: MyTrip.Schedule, calendar: Calendar = .manila) {
        let items = schedule.items.sorted { $0.startsAt < $1.startsAt }
        let byDay = Dictionary(grouping: items) { calendar.startOfDay(for: $0.startsAt) }
        days = byDay.keys.sorted().enumerated().map { index, day in
            Day(id: day, number: index + 1, items: byDay[day] ?? [])
        }
        self.items = items
        self.calendar = calendar
    }

    /// Today during the trip, otherwise the first day.
    func dayToOpen(now: Date) -> Day.ID? {
        let today = calendar.startOfDay(for: now)
        return days.first { $0.id == today }?.id ?? days.first?.id
    }

    /// The first item that hasn't started yet.
    func upNext(now: Date) -> MyTrip.ScheduleItem? {
        items.first { $0.startsAt > now }
    }

    func phase(of item: MyTrip.ScheduleItem, now: Date) -> Phase {
        if item.id == upNext(now: now)?.id {
            return .next
        }
        if now < item.startsAt {
            return .later
        }
        return now < end(of: item) ? .now : .past
    }

    /// Its own end, else when the next item starts, else the end of its day.
    private func end(of item: MyTrip.ScheduleItem) -> Date {
        if let endsAt = item.endsAt {
            return endsAt
        }
        let following = items.first { $0.startsAt > item.startsAt }
        if let following, calendar.isDate(following.startsAt, inSameDayAs: item.startsAt) {
            return following.startsAt
        }
        let dayStart = calendar.startOfDay(for: item.startsAt)
        return calendar.date(byAdding: .day, value: 1, to: dayStart) ?? item.startsAt
    }
}
