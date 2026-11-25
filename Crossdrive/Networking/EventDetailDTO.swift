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
    var waiver: WaiverDTO?
    var pay: PayDTO?

    enum CodingKeys: String, CodingKey {
        case event, summary, background, photos, roles, people, location, covers
        case notCovered, bringList, meetup, waiver, pay
        case registration = "me"
    }

    struct RoleDTO: Codable, Sendable {
        var id: String?
        var name: String?
        var summary: String?
        var icon: String?
        var slotsLeft: Int?
    }

    struct WaiverDTO: Codable, Sendable {
        var text: String?
        var pdfUrl: String?
    }

    struct PayDTO: Codable, Sendable {
        var qrUrl: String?
        var gcash: String?
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
