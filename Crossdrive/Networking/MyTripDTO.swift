/// One entry of `GET /me/trips`. Every field is optional; the mapper decides.
struct MyTripDTO: Codable, Sendable {
    var registration: RegistrationDTO?
    var event: EventDTO?
    var meetup: MeetupDTO?
    var lead: PersonDTO?
    var team: TeamDTO?
    var schedule: ScheduleDTO?
    var bring: [BringDTO]?
    var packed: [String]?
    var remindNightBefore: Bool?

    struct RegistrationDTO: Codable, Sendable {
        var id: String?
        var status: String?
        var waiverSigned: Bool?
        var paid: Bool?
        var permit: PermitDTO?
    }

    struct PermitDTO: Codable, Sendable {
        var name: String?
        var signed: Bool?
    }

    struct EventDTO: Codable, Sendable {
        var id: String?
        var kind: String?
        var name: String?
        var startsAt: String?
        var endsAt: String?
        var fee: Crossdrive.EventDTO.MoneyDTO?
        var payBy: String?
    }

    struct MeetupDTO: Codable, Sendable {
        var point: String?
        var startsAt: String?
        var latitude: Double?
        var longitude: Double?
    }

    struct PersonDTO: Codable, Sendable {
        var name: String?
        var phone: String?
    }

    struct TeamDTO: Codable, Sendable {
        var id: String?
        var name: String?
    }

    struct ScheduleDTO: Codable, Sendable {
        var published: Bool?
        var updatedAt: String?
        var items: [ItemDTO]?
    }

    struct ItemDTO: Codable, Sendable {
        var id: String?
        var startsAt: String?
        var endsAt: String?
        var title: String?
        var summary: String?
        var place: String?
        var latitude: Double?
        var longitude: Double?
        var team: TeamDTO?
        var bring: String?
        var ask: PersonDTO?
        var movedFrom: String?
    }

    struct BringDTO: Codable, Sendable {
        var id: String?
        var title: String?
    }
}
