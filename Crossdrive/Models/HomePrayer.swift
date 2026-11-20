import Foundation

/// A prayer point with how many people have prayed it. The Ministry page shows one.
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
