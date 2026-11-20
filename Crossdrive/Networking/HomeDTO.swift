/// What the server sends for Home. Every field the server may leave out is
/// optional; `HomeMapper` decides what to drop.
struct HomeDTO: Codable, Sendable {
    var nextEvent: EventDTO?
    var prayerPoint: PrayerDTO?
    var latestStory: StoryDTO?

    struct PrayerDTO: Codable, Sendable {
        var id: String?
        var body: String?
        var prayedCount: Int?
    }

    struct StoryDTO: Codable, Sendable {
        var id: String?
        var title: String?
        var summary: String?
        var imageURL: String?
    }
}
