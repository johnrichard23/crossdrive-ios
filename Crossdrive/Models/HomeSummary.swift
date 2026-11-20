import Foundation

/// What Home shows. Every part may be missing.
struct HomeSummary: Hashable, Sendable {
    var nextEvent: Event?
    var prayerPoint: HomePrayer?
    var latestStory: HomeStory?

    /// Nothing to show at all.
    var isEmpty: Bool {
        nextEvent == nil && prayerPoint == nil && latestStory == nil
    }
}

/// Today's prayer point.
struct HomePrayer: Identifiable, Hashable, Sendable {
    let id: String
    var body: String
    var prayedCount: Int

    /// "47 people prayed", "1 person prayed", or `nil` when nobody has.
    var prayedLabel: String? {
        switch prayedCount {
        case ..<1: nil
        case 1: "1 person prayed"
        default: "\(prayedCount) people prayed"
        }
    }
}

/// The latest story, as a card on Home.
struct HomeStory: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var summary: String
    var imageURL: URL?
}
