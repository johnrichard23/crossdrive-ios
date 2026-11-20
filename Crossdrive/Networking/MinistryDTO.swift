/// What the server sends for a ministry. Every field the server may leave out
/// is optional; `MinistryMapper` decides what to drop.
struct MinistryDTO: Codable, Sendable {
    var id: String?
    var name: String?
    var schedule: String?
    var place: String?
    var summary: String?
    var imageURL: String?
}
