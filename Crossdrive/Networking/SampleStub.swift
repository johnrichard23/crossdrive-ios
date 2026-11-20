import DataLayer
import Foundation

/// Canned server replies, so the app and its previews run with no backend.
/// Launch the Debug app with `-stub-api` to use them (the Xcode scheme does).
///
/// Sign in with any email and password, except the password `wrong`, which
/// is rejected, so the error state can be seen.
enum SampleStub {
    static let itemsJSON = """
    [
      {"id": "1", "title": "Coffee beans", "summary": "Whole bean, medium roast", "isFavorite": true},
      {"id": "2", "title": "Notebook", "summary": "Dot grid, A5"},
      {"id": "3", "title": "Desk lamp", "summary": "Warm light, dimmable"},
      {"id": "4", "title": "Water bottle", "summary": "Insulated, 750 ml"},
      {"id": "5", "title": "Headphones", "summary": "Over-ear, wired"}
    ]
    """

    /// The Home reply; `-stub-home-going` shows the same trip for a person who is going.
    static func homeJSON(going: Bool = false) -> String {
        let registration = going
            ? #""me": {"status": "going", "waiverSigned": false, "paid": false},"#
            : ""
        let meetup = going ? #""meetup": {"point": "Magallanes port", "time": "5:30 AM"},"# : ""
        return """
        {
          "nextTrip": {
            "event": {
              "id": "behia", "kind": "trip", "title": "Behia Mission Trip",
              "place": "Bagatao Island", "travelTime": "1 hr by boat",
              "startsAt": "2026-12-11T22:00:00Z", "endsAt": "2026-12-14T10:00:00Z",
              "fee": {"amountMinor": 150000, "currency": "PHP"},
              "capacity": 34, "registeredCount": 22, "status": "open",
              "heroImageURL": "https://images.pexels.com/photos/23499309/pexels-photo-23499309.jpeg?auto=compress&w=600"
            },
            "fromPlace": "Magallanes",
            \(registration)
            \(meetup)
            "ready": true
          },
          "latestStory": {
            "id": "s1", "title": "Kwento ng Behia", "quote": "Salamat, Behia.",
            "madeBy": "Made by the youth of Behia",
            "imageURL": "https://images.pexels.com/photos/1739842/pexels-photo-1739842.jpeg?auto=compress&w=900",
            "filmURL": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "hasConsent": true
          }
        }
        """
    }

    static let eventsJSON = """
    [
      {
        "id": "behia", "kind": "trip", "title": "Behia Mission Trip",
        "place": "Bagatao Island", "travelTime": "1 hr by boat",
        "startsAt": "2026-12-11T22:00:00Z", "endsAt": "2026-12-14T10:00:00Z",
        "fee": {"amountMinor": 150000, "currency": "PHP"},
        "capacity": 34, "registeredCount": 22, "status": "open",
        "heroImageURL": "https://images.pexels.com/photos/23499309/pexels-photo-23499309.jpeg?auto=compress&w=800"
      },
      {
        "id": "camp-feb", "kind": "camp", "title": "Young Missionaries Camp", "place": "Venue to be announced",
        "startsAt": "2027-02-19T22:00:00Z", "endsAt": "2027-02-22T04:00:00Z",
        "fee": {"amountMinor": 100000, "currency": "PHP"},
        "capacity": 30, "registeredCount": 12, "status": "open",
        "heroImageURL": "https://images.pexels.com/photos/33714873/pexels-photo-33714873.jpeg?auto=compress&w=800"
      }
    ]
    """

    /// The trip detail for `id`. "behia-going", "behia-full" and "bulan" are
    /// the going, full and mainland examples; any other id is the guest view.
    static func eventDetailJSON(for id: String) -> String {
        switch id {
        case "behia-going": behiaJSON(id: id, registration: goingMe, meetup: behiaMeetup)
        case "behia-full": behiaJSON(id: id, status: "full", registered: 34)
        case "bulan": bulanJSON
        default: behiaJSON(id: id)
        }
    }

    private static let goingMe = #""me": {"status": "going", "waiverSigned": false, "paid": false},"#
    private static let behiaMeetup = #""meetup": {"point": "Magallanes port", "time": "5:30 AM"},"#

    private static func behiaJSON(
        id: String,
        status: String = "open",
        registered: Int = 22,
        registration: String = "",
        meetup: String = ""
    ) -> String {
        """
        {
          "event": {
            "id": "\(id)", "kind": "trip", "title": "Behia Mission Trip",
            "place": "Bagatao Island", "travelTime": "1 hr by boat",
            "startsAt": "2026-12-11T22:00:00Z", "endsAt": "2026-12-14T10:00:00Z",
            "fee": {"amountMinor": 150000, "currency": "PHP"},
            "capacity": 34, "registeredCount": \(registered), "status": "\(status)",
            "heroImageURL": "https://images.pexels.com/photos/23499309/pexels-photo-23499309.jpeg?auto=compress&w=1200"
          },
          "summary": "Many families here have not heard the good news about Jesus yet.",
          "background": "Most families fish for a living. Children walk to the village school, \
        and the team has visited every year since 2023.",
          "people": 1200,
          "location": {"name": "Bagatao Island", "area": "Magallanes, Sorsogon",
                       "latitude": 12.8075, "longitude": 123.8761},
          "covers": [{"id": "boat", "name": "Boat", "icon": "boat"},
                     {"id": "meals", "name": "Meals", "icon": "meals"},
                     {"id": "stay", "name": "Stay", "icon": "stay"}],
          "notCovered": "fare to Magallanes and snacks",
          "roles": [
            {"id": "kids", "name": "Kids' camp", "summary": "Songs, stories and games", "icon": "kids"},
            {"id": "cooking", "name": "Cooking", "summary": "We cook and eat with the families", "icon": "cooking"}
          ],
          "bringList": ["Bible and notebook", "Water bottle", "Towel and slippers", "Light rain jacket"],
          \(registration)
          \(meetup)
          "photos": []
        }
        """
    }

    private static let bulanJSON = """
    {
      "event": {
        "id": "bulan", "kind": "trip", "title": "Bulan Mission Trip",
        "place": "Bulan, Sorsogon", "travelTime": "2 hr by van",
        "startsAt": "2027-01-15T22:00:00Z", "endsAt": "2027-01-18T10:00:00Z",
        "fee": {"amountMinor": 120000, "currency": "PHP"},
        "capacity": 30, "registeredCount": 22, "status": "open"
      },
      "summary": "Many families here have not heard the good news about Jesus yet.",
      "background": "Most families farm rice and coconut. The village has one small school, \
    and the team has come twice before.",
      "people": 800,
      "location": {"name": "Barangay Zone 5", "area": "Bulan, Sorsogon",
                   "latitude": 12.6694, "longitude": 123.8756},
      "covers": [{"id": "van", "name": "Van", "icon": "van"},
                 {"id": "meals", "name": "Meals", "icon": "meals"},
                 {"id": "stay", "name": "Billeting", "icon": "stay"}],
      "notCovered": "fare to Sorsogon City and snacks",
      "roles": [
        {"id": "kids", "name": "Kids' camp", "summary": "Songs, stories and games", "icon": "kids"},
        {"id": "health", "name": "Health help", "summary": "Checkups and vitamins", "icon": "health"}
      ],
      "bringList": ["Bible and notebook", "Water bottle", "Sleeping mat and pillow", "Insect repellent"],
      "photos": []
    }
    """

    static let ministriesJSON = """
    [
      {
        "id": "bible-studies", "name": "Community Bible studies", "schedule": "Every week",
        "place": "Gatbo, Bacon, Sorsogon City",
        "summary": "We visit a community each week and study the Bible in their place.",
        "imageURL": "https://images.pexels.com/photos/13011294/pexels-photo-13011294.jpeg?auto=compress&w=800"
      },
      {
        "id": "kids-class", "name": "Sunday kids' class", "schedule": "Every Sunday",
        "place": "Center location to be announced",
        "summary": "Kids learn about Jesus and the Bible at our center.",
        "imageURL": "https://images.pexels.com/photos/8613091/pexels-photo-8613091.jpeg?auto=compress&w=800"
      }
    ]
    """

    static let ministryDetailJSON = """
    {
      "ministry": {
        "id": "bible-studies", "name": "Community Bible studies", "schedule": "Every week",
        "place": "Gatbo, Bacon, Sorsogon City",
        "summary": "Every week we visit a community and study the Bible in their place.",
        "imageURL": "https://images.pexels.com/photos/13011294/pexels-photo-13011294.jpeg?auto=compress&w=800"
      },
      "photos": [
        {"url": "https://images.pexels.com/photos/13011294/pexels-photo-13011294.jpeg?auto=compress&w=500",
         "caption": "Reading the Bible together"},
        {"url": "https://images.pexels.com/photos/38186695/pexels-photo-38186695.jpeg?auto=compress&w=500",
         "caption": "Sharing a meal with the families"},
        {"url": "https://images.pexels.com/photos/13040204/pexels-photo-13040204.jpeg?auto=compress&w=500",
         "caption": "Children from the community"},
        {"url": "https://images.pexels.com/photos/16934870/pexels-photo-16934870.jpeg?auto=compress&w=500",
         "caption": "Families we visit"}
      ],
      "updates": [
        {"id": "u1", "postedAt": "2026-11-09T02:00:00Z",
         "text": "We finished the study on Psalm 23 with 14 families in Gatbo.",
         "imageURL": "https://images.pexels.com/photos/13011294/pexels-photo-13011294.jpeg?auto=compress&w=200"},
        {"id": "u2", "postedAt": "2026-11-02T02:00:00Z",
         "text": "Eight new families joined us this week. Thank you for praying.",
         "imageURL": "https://images.pexels.com/photos/38186695/pexels-photo-38186695.jpeg?auto=compress&w=200"}
      ],
      "prayer": {"id": "p1", "body": "For the families we visit this week.", "prayedCount": 31},
      "need": {
        "title": "Bibles and a place to meet for the studies",
        "raised": {"amountMinor": 1200000, "currency": "PHP"},
        "goal": {"amountMinor": 3000000, "currency": "PHP"}
      }
    }
    """

    static let signInJSON = """
    {"accessToken": "stub-access", "refreshToken": "stub-refresh", "expiresIn": 3600,
     "user": {"id": "stub-user", "name": "Sample User"}}
    """

    @Sendable
    static func handle(_ endpoint: Endpoint) async throws -> HTTPResponse {
        switch (endpoint.method, endpoint.path) {
        case (.get, "items"):
            return .json(itemsJSON)
        case (.get, _) where endpoint.path.hasPrefix("events/"):
            return .json(eventDetailJSON(for: String(endpoint.path.dropFirst("events/".count))))
        case (.get, _) where endpoint.path.hasPrefix("ministries/"):
            return .json(ministryDetailJSON)
        case (.get, "ministries"):
            return .json(ministriesJSON)
        case (.get, "events"):
            return .json(eventsJSON)
        case (.get, "home"):
            return .json(homeJSON(going: CommandLine.arguments.contains("-stub-home-going")))
        case (.post, "auth/sign-in"):
            let fields = endpoint.body.flatMap { try? JSONDecoder().decode(
                [String: String].self,
                from: $0
            ) }
            if fields?["password"] == "wrong" {
                return .json(#"{"message": "Incorrect email or password."}"#, status: 401)
            }
            return .json(signInJSON)
        case (.post, "auth/refresh"):
            return .json(#"{"accessToken": "stub-access-2", "expiresIn": 3600}"#)
        default:
            return .json("{}")
        }
    }
}
