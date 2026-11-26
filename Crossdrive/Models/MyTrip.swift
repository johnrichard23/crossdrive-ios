import Foundation

/// A trip the person joined: their registration, the trip's logistics, the
/// packing list and the schedule. Saved on the phone so it opens offline.
struct MyTrip: Identifiable, Codable, Hashable, Sendable {
    enum Status: String, Codable, Hashable, Sendable {
        case pending
        case going
        case waitlisted
    }

    /// Something left to do before the trip, in the order it is shown.
    enum ToDo: Hashable, Sendable {
        case fee(Money, payBy: Date?)
        case permit(name: String)
        case waiver
    }

    struct TripSummary: Codable, Hashable, Sendable {
        var kind: EventKind
        var name: String
        var place: String?
        var heroImageURL: URL?
        var startsAt: Date
        var endsAt: Date
        var fee: Money?
        var payBy: Date?
    }

    struct Meetup: Codable, Hashable, Sendable {
        var point: String
        var startsAt: Date
        var latitude: Double?
        var longitude: Double?
    }

    struct Lead: Codable, Hashable, Sendable {
        var name: String
        var phone: String?
    }

    struct Team: Codable, Hashable, Sendable {
        var id: String
        var name: String
    }

    struct Permit: Codable, Hashable, Sendable {
        var name: String
        var signed: Bool
    }

    struct BringItem: Identifiable, Codable, Hashable, Sendable {
        let id: String
        var title: String
    }

    struct Schedule: Codable, Hashable, Sendable {
        var published: Bool
        var updatedAt: Date?
        var items: [ScheduleItem]
    }

    struct ScheduleItem: Identifiable, Codable, Hashable, Sendable {
        let id: String
        var startsAt: Date
        var endsAt: Date?
        var title: String
        var summary: String?
        var place: String?
        var latitude: Double?
        var longitude: Double?
        var team: Team?
        var bring: String?
        var ask: Lead?
        /// The time it had before the coordinators moved it.
        var movedFrom: Date?
    }

    /// The event's id: a person has one registration per trip.
    let id: Event.ID
    let registrationID: String
    var status: Status
    var waiverSigned: Bool
    var paid: Bool
    var permit: Permit?
    var event: TripSummary
    var meetup: Meetup?
    var lead: Lead?
    var team: Team?
    /// Only sent to confirmed volunteers.
    var schedule: Schedule?
    var bring: [BringItem]
    var packed: Set<BringItem.ID>
    var remindNightBefore: Bool

    /// What is still open. Nothing for the waiting list: there is no fee yet.
    var toDos: [ToDo] {
        guard status != .waitlisted else { return [] }
        var toDos: [ToDo] = []
        if !paid, let fee = event.fee {
            toDos.append(.fee(fee, payBy: event.payBy))
        }
        if let permit, !permit.signed {
            toDos.append(.permit(name: permit.name))
        }
        if !waiverSigned {
            toDos.append(.waiver)
        }
        return toDos
    }

    /// Only items still on the list count.
    var packedCount: Int {
        bring.filter { packed.contains($0.id) }.count
    }

    func hasEnded(now: Date) -> Bool {
        now >= event.endsAt
    }

    /// "The trip starts tomorrow", counted in calendar days where the trip is.
    func countdown(now: Date, calendar: Calendar = .manila) -> String {
        guard !hasEnded(now: now) else { return String(localized: "The trip has ended") }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: event.startsAt)
        ).day ?? 0
        switch days {
        case ..<0: return String(localized: "The trip is on now")
        case 0: return String(localized: "The trip starts today")
        case 1: return String(localized: "The trip starts tomorrow")
        default: return String(localized: "The trip starts in \(days) days")
        }
    }

    var statusLine: String {
        switch status {
        case .going: String(localized: "You're going")
        case .pending: String(localized: "Waiting for a coordinator")
        case .waitlisted: String(localized: "On the waiting list")
        }
    }
}

extension Calendar {
    /// Trips run on Philippine time, wherever the phone is set.
    static let manila: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Manila") ?? .current
        return calendar
    }()
}
