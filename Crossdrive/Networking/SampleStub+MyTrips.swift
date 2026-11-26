import Foundation

/// The canned `GET /me/trips` reply: going to Behia (fee and permit open, the
/// schedule out), waitlisted for Bulan, and waiting for a coordinator on the
/// camp. `-stub-schedule-unpublished` holds Behia's schedule back.
extension SampleStub {
    private static let behiaPhoto =
        "https://images.pexels.com/photos/23499309/pexels-photo-23499309.jpeg?auto=compress&w=800"
    private static let campPhoto =
        "https://images.pexels.com/photos/33714873/pexels-photo-33714873.jpeg?auto=compress&w=800"

    static var myTripsJSON: String {
        let published = !CommandLine.arguments.contains("-stub-schedule-unpublished")
        return #"""
        [
          {"registration": {"id": "reg-behia", "status": "going", "waiverSigned": true, "paid": false,
                            "permit": {"name": "Maria Bañares", "signed": false}},
           "event": {"id": "behia-going", "kind": "trip", "name": "Behia Mission Trip", "place": "Bagatao Island",
                     "heroImageURL": "\#(behiaPhoto)",
                     "startsAt": "2026-12-11T22:00:00Z", "endsAt": "2026-12-14T10:00:00Z",
                     "fee": {"amountMinor": 150000, "currency": "PHP"}, "payBy": "2026-12-11T16:00:00Z"},
           "meetup": {"point": "Magallanes port", "startsAt": "2026-12-11T21:30:00Z",
                      "latitude": 12.8270, "longitude": 123.8360},
           "lead": {"name": "Mark", "phone": "09171234567"},
           "team": {"id": "film", "name": "Film crew"},
           "schedule": \#(behiaSchedule(published: published)),
           "bring": [{"id": "water", "title": "Water bottle"},
                     {"id": "hat", "title": "Hat and sunscreen"},
                     {"id": "clothes", "title": "Change of clothes"},
                     {"id": "bible", "title": "Bible and notebook"},
                     {"id": "id", "title": "Valid ID"}],
           "packed": ["water", "hat"],
           "remindNightBefore": true},
          {"registration": {"id": "reg-bulan", "status": "waitlisted", "waiverSigned": true, "paid": false},
           "event": {"id": "bulan", "kind": "trip", "name": "Bulan Mission Trip", "place": "Bulan, Sorsogon",
                     "startsAt": "2027-01-15T22:00:00Z", "endsAt": "2027-01-18T10:00:00Z",
                     "fee": {"amountMinor": 150000, "currency": "PHP"}},
           "bring": [{"id": "water", "title": "Water bottle"}]},
          {"registration": {"id": "reg-camp", "status": "pending", "waiverSigned": true, "paid": false},
           "event": {"id": "camp-feb", "kind": "camp", "name": "Young Missionaries Camp",
                     "place": "Venue to be announced",
                     "heroImageURL": "\#(campPhoto)",
                     "startsAt": "2027-02-19T22:00:00Z", "endsAt": "2027-02-22T04:00:00Z"},
           "bring": [{"id": "bible", "title": "Bible and notebook"}]}
        ]
        """#
    }

    private static func behiaSchedule(published: Bool) -> String {
        guard published else { return #"{"published": false}"# }
        return #"""
        {"published": true, "updatedAt": "2026-12-11T22:10:00Z", "items": [
          {"id": "boat", "startsAt": "2026-12-11T22:00:00Z", "endsAt": "2026-12-11T23:30:00Z",
           "title": "Boat to Bagatao Island", "place": "Magallanes port", "latitude": 12.8270, "longitude": 123.8360},
          {"id": "settle", "startsAt": "2026-12-12T00:00:00Z", "title": "Settle in at the chapel",
           "place": "Behia chapel"},
          {"id": "kids", "startsAt": "2026-12-12T01:00:00Z", "endsAt": "2026-12-12T02:30:00Z",
           "title": "Kids' camp, first session", "place": "Chapel yard",
           "team": {"id": "kids", "name": "Kids' camp"}},
          {"id": "film", "startsAt": "2026-12-12T02:45:00Z", "endsAt": "2026-12-12T04:00:00Z",
           "title": "Film workshop with the youth",
           "summary": "We teach three local youth to shoot and edit a short film about Behia.",
           "place": "Behia school", "latitude": 12.8410, "longitude": 123.8590,
           "team": {"id": "film", "name": "Film crew"}, "bring": "The camera kit and spare batteries.",
           "ask": {"name": "Mark", "phone": "09171234567"}, "movedFrom": "2026-12-12T02:30:00Z"},
          {"id": "lunch", "startsAt": "2026-12-12T04:00:00Z", "title": "Lunch with the families",
           "place": "Chapel yard"},
          {"id": "worship", "startsAt": "2026-12-12T10:00:00Z", "title": "Worship night",
           "place": "Behia chapel"},
          {"id": "clinic", "startsAt": "2026-12-13T01:00:00Z", "title": "Health check for the families",
           "place": "Behia chapel"},
          {"id": "home", "startsAt": "2026-12-14T06:00:00Z", "title": "Boat back to Magallanes",
           "place": "Bagatao pier"}
        ]}
        """#
    }
}
