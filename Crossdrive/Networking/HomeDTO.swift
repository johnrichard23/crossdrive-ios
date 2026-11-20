struct HomeDTO: Codable, Sendable {
    var nextTrip: HomeTripDTO?
    var latestStory: HomeStoryDTO?
}

struct HomeTripDTO: Codable, Sendable {
    var event: EventDTO?
    var fromPlace: String?
    var registration: EventDetailDTO.MeDTO?
    var meetup: EventDetailDTO.MeetupDTO?

    enum CodingKeys: String, CodingKey {
        case event, fromPlace, meetup
        case registration = "me"
    }
}

struct HomeStoryDTO: Codable, Sendable {
    var id: String?
    var title: String?
    var quote: String?
    var madeBy: String?
    var imageURL: String?
    var filmURL: String?
    var hasConsent: Bool?
}
