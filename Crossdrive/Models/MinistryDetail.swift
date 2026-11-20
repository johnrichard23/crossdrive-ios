import Foundation

/// A ministry with everything its detail screen shows. Every part but the
/// ministry itself may be missing.
struct MinistryDetail: Hashable, Sendable {
    var ministry: Ministry
    var photos: [MinistryPhoto]
    var updates: [MinistryUpdate]
    var prayer: HomePrayer?
    var need: MinistryNeed?
}

/// A photo from a ministry. The caption is what VoiceOver reads.
struct MinistryPhoto: Identifiable, Hashable, Sendable {
    let url: URL
    var caption: String

    var id: URL {
        url
    }
}

/// A short update from the team.
struct MinistryUpdate: Identifiable, Hashable, Sendable {
    let id: String
    var text: String
    var postedAt: Date?
    var imageURL: URL?

    /// "Nov 9", in Manila time. `nil` when the server sent no date.
    var dateLabel: String? {
        guard let postedAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "Asia/Manila")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: postedAt)
    }
}

/// What a ministry needs, and how much of it has been given.
struct MinistryNeed: Hashable, Sendable {
    var title: String
    var raised: Money
    var goal: Money

    /// How far along the goal is, from 0 to 1. A goal of zero counts as 0.
    var fraction: Double {
        guard goal.amountMinor > 0 else { return 0 }
        return min(max(Double(raised.amountMinor) / Double(goal.amountMinor), 0), 1)
    }
}
