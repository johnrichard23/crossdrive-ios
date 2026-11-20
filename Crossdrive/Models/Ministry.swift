import Foundation

/// A ministry CrossDrive runs, such as the weekly community Bible studies.
struct Ministry: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    /// How often it happens: "Every week", "Every Sunday".
    var schedule: String?
    /// Where it happens: "Gatbo, Bacon, Sorsogon City".
    var place: String?
    var summary: String
    var imageURL: URL?
}
