struct EventDetailDTO: Codable, Sendable {
    var event: EventDTO?
    var summary: String?
    var background: String?
    var photos: [String]?
    var roles: [RoleDTO]?
    var people: Int?
    var location: LocationDTO?
    var covers: [CoverDTO]?
    var notCovered: String?
    var bringList: [String]?
    var registration: MeDTO?
    var meetup: MeetupDTO?

    enum CodingKeys: String, CodingKey {
        case event, summary, background, photos, roles, people, location, covers
        case notCovered, bringList, meetup
        case registration = "me"
    }

    struct RoleDTO: Codable, Sendable {
        var id: String?
        var name: String?
        var summary: String?
        var icon: String?
    }

    struct CoverDTO: Codable, Sendable {
        var id: String?
        var name: String?
        var icon: String?
    }

    struct LocationDTO: Codable, Sendable {
        var name: String?
        var area: String?
        var latitude: Double?
        var longitude: Double?
    }

    struct MeDTO: Codable, Sendable {
        var status: String?
        var waiverSigned: Bool?
        var paid: Bool?
    }

    struct MeetupDTO: Codable, Sendable {
        var point: String?
        var time: String?
    }
}
