/// What the server sends for a ministry. Every field the server may leave out
/// is optional; `MinistryMapper` decides what to drop.
struct MinistryDTO: Codable, Sendable {
    struct FundDTO: Codable, Sendable {
        var kidsPaid: Int?
        var kidsGoal: Int?
    }

    var id: String?
    var name: String?
    var schedule: String?
    var place: String?
    var summary: String?
    var imageURL: String?
    /// `bibleStudy`, `school` or `skill`; anything else is shown as other.
    var kind: String?
    var photos: [String]?
    var partner: String?
    var fund: FundDTO?
}
