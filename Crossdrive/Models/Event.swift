import Foundation

/// What kind of event it is. Conferences have no sign-up here, so they are not events.
enum EventKind: String, Hashable, Sendable, CaseIterable {
    case trip
    case camp

    /// The tag on an event card.
    var tagLabel: String {
        switch self {
        case .trip: "Mission trip"
        case .camp: "Camp"
        }
    }

    /// The filter chip's name.
    var chipLabel: String {
        switch self {
        case .trip: "Mission trips"
        case .camp: "Camps"
        }
    }
}

/// A mission trip or a camp, as the Home and Events screens show it.
struct Event: Identifiable, Hashable, Sendable {
    let id: String
    var kind: EventKind
    var title: String
    /// Where it happens, e.g. "Behia, Bagatao Island".
    var place: String?
    var startsAt: Date
    var endsAt: Date?
    /// "1 hr by boat". Free text from the trip; there is no fixed set of vehicles.
    var travelTime: String?
    var fee: Money?
    var capacity: Int?
    var registeredCount: Int
    var isClosed: Bool
    /// The server says no slots are left. A full trip can take a waitlist.
    var isFull = false
    var heroImageURL: URL?

    /// Every slot is taken, whatever the server's status says.
    var hasNoSlotsLeft: Bool {
        capacity.map { registeredCount >= $0 } ?? false
    }

    /// Sign-up is over although slots may be left (for example, the date has
    /// passed). A closed trip takes no waitlist, unlike a full one.
    var isClosedToSignUp: Bool {
        isClosed && !isFull
    }

    /// What the trip offers a person. Home and Trip detail share this one rule.
    func bar(registration: EventRegistration?) -> EventBar {
        if let registration, registration.status == .going {
            return .going(paid: registration.isPaid, waiverSigned: registration.waiverSigned)
        }
        if registration?.status == .waitlisted {
            return .waitlisted
        }
        if isClosedToSignUp {
            return .closed
        }
        if isFull || hasNoSlotsLeft {
            return .full
        }
        return .register
    }

    /// Whole days from today to the first day, in Manila time. 0 is today and
    /// a negative number means the trip has started.
    func daysUntilStart(from now: Date) -> Int {
        let calendar = Self.manilaCalendar
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: startsAt)
        ).day ?? 0
    }

    /// How many slots remain, or `nil` when there is no limit.
    var slotsLeftCount: Int? {
        capacity.map { max($0 - registeredCount, 0) }
    }

    /// "Dec 12 to 14", "Dec 30 to Jan 2" or "Dec 12", in Manila time.
    var dateRangeLabel: String {
        let start = Self.monthDay.format(startsAt)
        guard let endsAt else { return start }
        let end = Self.monthDay.format(endsAt)
        guard end != start else { return start }
        let sameMonth = Self.month.format(startsAt) == Self.month.format(endsAt)
        return "\(start) to \(sameMonth ? Self.dayOfMonth.format(endsAt) : end)"
    }

    /// "12 slots left", "1 slot left" or "Full". `nil` when there is no limit.
    var slotsLabel: String? {
        guard let capacity else { return isClosed ? "Full" : nil }
        let left = max(capacity - registeredCount, 0)
        if isClosed || left == 0 {
            return "Full"
        }
        return left == 1 ? "1 slot left" : "\(left) slots left"
    }

    /// "₱1,500 per person". What the fee covers is a list on the detail screen.
    var feeLabel: String? {
        fee.map { "\($0.formatted) per person" }
    }

    /// "Bagatao Island · 1 hr by boat", or whichever of the two the trip has.
    var placeLine: String? {
        let parts = [place, travelTime].compactMap(\.self).filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The travel time split for the band: ("1 hr", "by boat"). A time with no
    /// " by " keeps all of it as the value.
    var travelParts: (value: String, label: String)? {
        guard let travelTime, !travelTime.isEmpty else { return nil }
        guard let range = travelTime.range(of: " by ") else { return (travelTime, "travel") }
        return (
            String(travelTime[..<range.lowerBound]),
            "by " + travelTime[range.upperBound...]
        )
    }

    /// "Saturday, Dec 12", the first day in Manila time.
    var startDayLabel: String {
        Self.weekdayMonthDay.format(startsAt)
    }

    /// "12": the day of the month of the first day, in Manila time.
    var startDayNumber: String {
        Self.dayOfMonth.format(startsAt)
    }

    /// "December": the full month of the first day, for VoiceOver.
    var startMonthName: String {
        Self.monthName.format(startsAt)
    }

    /// "Dec": the month of the first day, in Manila time.
    var startMonthAbbreviation: String {
        Self.month.format(startsAt)
    }

    /// "Pay before Dec 12": the fee is due by the first day.
    var payBeforeLabel: String {
        "Pay before \(Self.monthDay.format(startsAt))"
    }

    /// The number of calendar days the event spans, in Manila time. `nil` with no end date.
    private var dayCount: Int? {
        guard let endsAt else { return nil }
        let calendar = Self.manilaCalendar
        let span = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startsAt),
            to: calendar.startOfDay(for: endsAt)
        ).day
        return span.map { $0 + 1 } ?? 1
    }

    /// "3 days, 2 nights" for the hero line, written with digits.
    var daysAndNights: String? {
        guard let days = dayCount else { return nil }
        guard days > 1 else { return "One day" }
        return "\(days) days, \(days - 1) \(days == 2 ? "night" : "nights")"
    }

    /// "22 of 34 slots taken". `nil` when there is no limit.
    var slotsTakenLabel: String? {
        guard let capacity else { return nil }
        return "\(min(registeredCount, capacity)) of \(capacity) slots taken"
    }

    /// How full the event is, from 0 to 1.
    var takenFraction: Double {
        guard let capacity, capacity > 0 else { return 0 }
        return min(Double(registeredCount) / Double(capacity), 1)
    }

    private static let manilaZone = TimeZone(identifier: "Asia/Manila") ?? .current

    private static var manilaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = manilaZone
        return calendar
    }

    /// Format styles are cheap value types, so they are built once, not on every redraw.
    private static func style() -> Date.FormatStyle {
        Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: Locale(identifier: "en_US"),
            calendar: manilaCalendar,
            timeZone: manilaZone
        )
    }

    private static let monthDay = style().month(.abbreviated).day()
    private static let month = style().month(.abbreviated)
    private static let monthName = style().month(.wide)
    private static let dayOfMonth = style().day()
    private static let weekdayMonthDay = style().weekday(.wide).month(.abbreviated).day()
}
