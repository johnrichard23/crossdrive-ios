/// What the server sends for a ministry. Every field the server may leave out
/// is optional; `MinistryMapper` decides what to drop.
struct MinistryDTO: Codable, Sendable {
    struct FundDTO: Codable, Sendable {
        var kidsPaid: Int?
        var kidsGoal: Int?
        var raised: EventDTO.MoneyDTO?
        var goal: EventDTO.MoneyDTO?
        var costs: [CostDTO]?
    }

    struct CostDTO: Codable, Sendable {
        var title: String?
        var amount: EventDTO.MoneyDTO?
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
