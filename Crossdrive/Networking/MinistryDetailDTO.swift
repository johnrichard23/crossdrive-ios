/// What the server sends for one ministry's detail screen.
struct MinistryDetailDTO: Codable, Sendable {
    var ministry: MinistryDTO?
    var photos: [PhotoDTO]?
    var updates: [UpdateDTO]?
    var prayer: PrayerDTO?
    var need: NeedDTO?

    struct PhotoDTO: Codable, Sendable {
        var url: String?
        var caption: String?
    }

    struct UpdateDTO: Codable, Sendable {
        var id: String?
        var text: String?
        var postedAt: String?
        var imageURL: String?
    }

    struct PrayerDTO: Codable, Sendable {
        var id: String?
        var body: String?
        var prayedCount: Int?
    }

    struct NeedDTO: Codable, Sendable {
        var title: String?
        var raised: EventDTO.MoneyDTO?
        var goal: EventDTO.MoneyDTO?
    }
}
