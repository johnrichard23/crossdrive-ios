import Foundation

/// A ministry CrossDrive runs, such as the weekly Bible study in one community.
struct Ministry: Identifiable, Hashable, Sendable {
    /// Which section of the Ministries list it belongs to.
    enum Kind: String, CaseIterable, Sendable {
        case bibleStudy
        case school
        case skill
        /// Anything the app doesn't know yet; still shown, under its own heading.
        case other
    }

    /// How many kids a school fund has paid for, out of how many it aims to,
    /// and how much it has raised this school year.
    struct Fund: Hashable, Sendable {
        var kidsPaid: Int
        var kidsGoal: Int
        /// `nil` when the server sent no amounts.
        var raised: Money?
        var goal: Money?
        /// What one kid needs for one month, item by item.
        var costs: [MinistryFundCost] = []

        /// How far along the goal is, from 0 to 1; 0 without amounts.
        var fraction: Double {
            guard let raised, let goal, goal.amountMinor > 0 else { return 0 }
            return min(max(Double(raised.amountMinor) / Double(goal.amountMinor), 0), 1)
        }

        /// What is still needed to reach the goal.
        var toGo: Money? {
            guard let raised, let goal else { return nil }
            return Money(
                amountMinor: max(goal.amountMinor - raised.amountMinor, 0),
                currency: goal.currency
            )
        }

        /// One kid for one month, in centavos; `nil` without costs.
        var kidMonthMinor: Int? {
            costs.isEmpty ? nil : costs.reduce(0) { $0 + $1.amount.amountMinor }
        }
    }

    let id: String
    var name: String
    /// How often it happens: "Every week", "Every Sunday".
    var schedule: String?
    /// Where it happens: "Gatbo, Bacon, Sorsogon City".
    var place: String?
    var summary: String
    var imageURL: URL?
    var kind: Kind = .other
    /// The photos for the list's photo grid, main one first.
    var photoURLs: [URL] = []
    /// Who runs a skills program with CrossDrive.
    var partner: String?
    var fund: Fund?

    /// The photo at the top of its page: the main one, else the first of the grid.
    var heroURL: URL? {
        imageURL ?? photoURLs.first
    }
}

/// One thing a school-fund kid needs each month, such as school fees.
struct MinistryFundCost: Hashable, Sendable {
    var title: String
    var amount: Money
}
