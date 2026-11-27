import Foundation

/// What the Profile card and its trips row show, worked out from the signed-in
/// person and the trips they joined.
struct ProfileSummary: Equatable {
    /// "JB" from "Joy Bañares"; empty when there is no name.
    let initials: String
    let name: String
    /// "3 trips", "1 trip" or "No trips yet".
    let tripsLine: String
    /// At most three: coming trips first, soonest first, then the ones that ended.
    let trips: [MyTrip]
    let hasMoreTrips: Bool

    static let tripsShown = 3

    init(user: AppUser, trips: [MyTrip], now: Date) {
        let words = (user.name ?? "").split(whereSeparator: \.isWhitespace)
        let letters = [words.first, words.count > 1 ? words.last : nil].compactMap { $0?.first }
        initials = String(letters).uppercased()
        name = user.name.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
            ?? String(localized: "Your account")
        tripsLine = switch trips.count {
        case 0: String(localized: "No trips yet")
        case 1: String(localized: "1 trip")
        default: String(localized: "\(trips.count) trips")
        }
        let coming = trips.filter { $0.event.endsAt >= now }
            .sorted { $0.event.startsAt < $1.event.startsAt }
        let ended = trips.filter { $0.event.endsAt < now }
            .sorted { $0.event.startsAt > $1.event.startsAt }
        self.trips = Array((coming + ended).prefix(Self.tripsShown))
        hasMoreTrips = trips.count > Self.tripsShown
    }
}
