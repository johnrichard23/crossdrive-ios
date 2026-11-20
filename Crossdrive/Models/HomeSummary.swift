import Foundation

/// What Home shows: the next trip, and the latest story. Either can be missing.
struct HomeSummary: Hashable, Sendable {
    var trip: HomeTrip?
    var latestStory: HomeStory?

    var isEmpty: Bool {
        trip == nil && latestStory == nil
    }
}

/// The next trip, with what is known about the person's place on it.
struct HomeTrip: Hashable, Sendable {
    var event: Event
    /// A town or area for the route line ("Magallanes"). Never the exact meeting
    /// point, which only people who are going may see.
    var fromPlace: String?
    /// `nil` for a guest.
    var registration: EventRegistration?
    /// Only present when the person is going.
    var meetup: EventMeetup?

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

    /// The route line's two ends ("Magallanes", "Bagatao Island"); `nil` unless both are known.
    var route: (origin: String, destination: String)? {
        guard let origin = fromPlace, !origin.isEmpty, let destination = event.place,
              !destination.isEmpty
        else {
            return nil
        }
        return (origin, destination)
    }

    /// The big number and the words under it, for the day `now`. `nil` once the
    /// trip is over.
    func countdown(now: Date) -> HomeCountdown? {
        if let endsAt = event.endsAt, now > endsAt {
            return nil
        }
        let title = event.title
        switch event.daysUntilStart(from: now) {
        case ..<0: return HomeCountdown(number: "Now", caption: "the \(title) is on")
        case 0: return HomeCountdown(number: "Today", caption: "the \(title) begins")
        case 1: return HomeCountdown(number: "1", caption: "day until the \(title)")
        case let days: return HomeCountdown(number: "\(days)", caption: "days until the \(title)")
        }
    }
}

struct HomeCountdown: Hashable, Sendable {
    var number: String
    var caption: String
}

/// The latest mission story, shown as the film card.
struct HomeStory: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    /// The line on the card ("Salamat, Behia.").
    var quote: String
    /// "Made by the youth of Behia".
    var madeBy: String?
    var imageURL: URL?
    /// The film, opened in the system web view. HTTPS only.
    var filmURL: URL?
}
