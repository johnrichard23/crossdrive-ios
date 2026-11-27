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

    /// How many kids a school fund has paid for, out of how many it aims to.
    struct Fund: Hashable, Sendable {
        var kidsPaid: Int
        var kidsGoal: Int
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
}
