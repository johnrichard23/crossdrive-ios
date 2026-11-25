import Foundation

/// One event with everything the detail screen shows. Every part past `event`
/// is optional on the wire, so a missing part is an empty one here.
struct EventDetail: Hashable, Sendable {
    var event: Event
    /// The line quoted under "Why we go".
    var summary: String
    /// The text under the quote.
    var background: String
    var photoURLs: [URL]
    var roles: [EventRole]
    var peopleCount: Int?
    var location: EventLocation?
    var covers: [EventCover]
    /// "fare to Magallanes and snacks".
    var notCovered: String?
    var bringList: [String]
    /// `nil` for a guest.
    var registration: EventRegistration?
    /// Only present when the person is going.
    var meetup: EventMeetup?
    /// What a person signs to register. `nil` when the trip has not published one yet.
    var waiver: EventWaiver?
    /// How to pay the fee: CrossDrive's own QR code and GCash number, from the server.
    var pay: EventPay?

    /// What the pinned bar offers, in the order the rules apply.
    var bar: EventBar {
        event.bar(registration: registration)
    }

    var isGoing: Bool {
        if case .going = bar {
            true
        } else {
            false
        }
    }

    /// 2 to 4 covered items sit in a grid; more than that is a list.
    var coversFitGrid: Bool {
        (2 ... 4).contains(covers.count)
    }

    /// The facts in the pine band, left to right. A fact the trip does not have is left out.
    var bandStats: [EventBandStat] {
        var stats: [EventBandStat] = []
        if let people = peopleLabel {
            stats.append(EventBandStat(value: people, label: "people"))
        }
        if let travel = event.travelParts {
            stats.append(EventBandStat(value: travel.value, label: travel.label))
        }
        if let slots = slotsStat {
            stats.append(slots)
        }
        return stats
    }

    private var slotsStat: EventBandStat? {
        if isGoing {
            return EventBandStat(value: "\(event.registeredCount)", label: "going")
        }
        guard let capacity = event.capacity else { return nil }
        let left = capacity - event.registeredCount
        if event.isFull || left <= 0 {
            return EventBandStat(value: "Full", label: "no slots left")
        }
        return EventBandStat(value: "\(left)", label: left == 1 ? "slot left" : "slots left")
    }

    /// "1,200", for the band.
    var peopleLabel: String? {
        peopleCount.map { $0.formatted(.number.grouping(.automatic)) }
    }
}

struct EventBandStat: Hashable, Sendable {
    var value: String
    var label: String
}

enum EventBar: Hashable, Sendable {
    case register
    case full
    case waitlisted
    case closed
    case going(paid: Bool, waiverSigned: Bool)
}

struct EventRole: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var summary: String
    var iconKey: String?
    /// Places left on this team. `nil` when the team has no limit; 0 means full.
    var slotsLeft: Int?

    /// "3 slots left", "1 slot left" or "Full". `nil` when the team has no limit.
    var slotsLabel: String? {
        guard let slotsLeft else { return nil }
        if slotsLeft <= 0 {
            return "Full"
        }
        return slotsLeft == 1 ? "1 slot left" : "\(slotsLeft) slots left"
    }

    var isFull: Bool {
        (slotsLeft ?? 1) <= 0
    }
}

struct EventCover: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var iconKey: String?
}

struct EventLocation: Hashable, Sendable {
    var name: String
    /// "Magallanes, Sorsogon".
    var area: String?
    var latitude: Double
    var longitude: Double

    /// "Bagatao Island, Magallanes, Sorsogon".
    var caption: String {
        [name, area].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Apple Maps link. HTTPS; no location permission is needed to open it.
    var mapsURL: URL? {
        var parts = URLComponents(string: "https://maps.apple.com/")
        parts?.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: name),
        ]
        return parts?.url
    }
}

struct EventRegistration: Hashable, Sendable {
    enum Status: Hashable, Sendable {
        case going
        case waitlisted
    }

    var status: Status
    var waiverSigned: Bool
    var isPaid: Bool
}

struct EventMeetup: Hashable, Sendable {
    var point: String
    var time: String
}

struct EventWaiver: Hashable, Sendable {
    var text: String
    var pdfURL: URL?
}

/// Where a trip's fee goes. Both come from the server and only an admin
/// changes them (a swapped QR code is the main fraud risk in the app).
struct EventPay: Hashable, Sendable {
    var qrURL: URL?
    var gcashNumber: String?
}
