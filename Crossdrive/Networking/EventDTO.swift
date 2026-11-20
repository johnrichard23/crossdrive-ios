/// What the server sends for an event. Every field the server may leave out is
/// optional; `EventMapper` decides what to drop.
struct EventDTO: Codable, Sendable {
    var id: String?
    /// `trip` or `camp`.
    var kind: String?
    var title: String?
    var place: String?
    /// ISO 8601, UTC.
    var startsAt: String?
    var endsAt: String?
    var travelTime: String?
    var fee: MoneyDTO?
    var capacity: Int?
    var registeredCount: Int?
    var status: String?
    var heroImageURL: String?

    struct MoneyDTO: Codable, Sendable {
        var amountMinor: Int?
        var currency: String?
    }
}
