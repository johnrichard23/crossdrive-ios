import Foundation

/// Display text for a joined trip, in Manila time like the rest of the app.
extension MyTrip {
    /// The trip as an `Event`, to reuse its date and place labels.
    var eventForLabels: Event {
        Event(
            id: id,
            kind: event.kind,
            title: event.name,
            place: event.place,
            startsAt: event.startsAt,
            endsAt: event.endsAt,
            travelTime: nil,
            fee: event.fee,
            capacity: nil,
            registeredCount: 0,
            isClosed: false,
            heroImageURL: event.heroImageURL
        )
    }

    /// "Dec 12 to 14".
    var dateRangeLabel: String {
        eventForLabels.dateRangeLabel
    }

    /// "Meet Sat, Dec 12 · 5:30 AM, Magallanes port".
    var meetLine: String? {
        guard let meetup else { return nil }
        let day = Self.shortDay.format(meetup.startsAt)
        let time = Self.time.format(meetup.startsAt)
        return String(localized: "Meet \(day) · \(time), \(meetup.point)")
    }

    /// "₱1,500 · not paid yet" or "₱1,500 · Paid". `nil` when there is no fee.
    var feeLine: String? {
        guard let fee = event.fee else { return nil }
        return paid
            ? String(localized: "\(fee.formatted) · Paid")
            : String(localized: "\(fee.formatted) · not paid yet")
    }

    /// "Bagatao Island · Dec 12 to 14".
    var placeAndDates: String {
        [event.place, dateRangeLabel].compactMap(\.self).joined(separator: " · ")
    }

    static let time = style().hour().minute()
    /// "Sat, Dec 12".
    static let shortDay = style().weekday(.abbreviated).month(.abbreviated).day()
    /// "Saturday, Dec 12".
    static let longDay = style().weekday(.wide).month(.abbreviated).day()
    /// "Dec 12".
    static let monthDay = style().month(.abbreviated).day()
    /// "Sat".
    static let weekday = style().weekday(.abbreviated)
    /// "12".
    static let dayOfMonth = style().day()
    /// "10:30", for a time shown with its AM or PM apart.
    static let clock = style().hour(.defaultDigits(amPM: .omitted)).minute()

    /// "AM" or "PM" for a time in Manila.
    static func dayPeriod(_ date: Date) -> String {
        let calendar = periodCalendar
        return calendar.component(.hour, from: date) < 12 ? calendar.amSymbol : calendar.pmSymbol
    }

    /// Manila time with the same locale as the formatters above.
    private static let periodCalendar: Calendar = {
        var calendar = Calendar.manila
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    private static func style() -> Date.FormatStyle {
        Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: Locale(identifier: "en_US"),
            calendar: .manila,
            timeZone: Calendar.manila.timeZone
        )
    }
}

extension MyTrip.ToDo {
    /// The row's title in the to-do sheet.
    var title: String {
        switch self {
        case .fee: String(localized: "Trip fee not paid yet")
        case .permit: String(localized: "Guardian permit waiting")
        case .waiver: String(localized: "Waiver not signed yet")
        }
    }

    /// The row's second line.
    var detail: String {
        switch self {
        case let .fee(money, payBy):
            if let payBy {
                String(localized: "\(money.formatted), before \(MyTrip.monthDay.format(payBy))")
            } else {
                money.formatted
            }
        case let .permit(name):
            String(localized: "\(name) hasn't signed yet.")
        case .waiver:
            String(localized: "Sign it before you board. It takes a minute.")
        }
    }

    /// The banner's second line names each open item: "Trip fee and guardian permit".
    var shortName: String {
        switch self {
        case .fee: String(localized: "Trip fee")
        case .permit: String(localized: "guardian permit")
        case .waiver: String(localized: "waiver")
        }
    }
}
