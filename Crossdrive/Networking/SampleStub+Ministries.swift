import DataLayer
import Foundation

/// The canned `GET /ministries` reply: three Bible-study communities, the
/// school fund and three skills programs.
extension SampleStub {
    private static func photo(_ id: Int, width: Int = 600) -> String {
        "https://images.pexels.com/photos/\(id)/pexels-photo-\(id).jpeg?auto=compress&w=\(width)"
    }

    private static let bible = 13_011_294
    private static let meal = 38_186_695
    private static let families = 16_934_870

    /// One ministry's page: its own name, place and photos from the list, with
    /// the same photos, updates, prayer and need as the Bible studies. A
    /// ministry that isn't on the list is not found.
    static func ministryDetailReply(id: String) -> HTTPResponse {
        let list = (try? JSONSerialization
            .jsonObject(with: Data(ministriesJSON.utf8))) as? [[String: Any]]
        guard let ministry = list?.first(where: { $0["id"] as? String == id }),
              var detail = (try? JSONSerialization.jsonObject(with: Data(ministryDetailJSON.utf8)))
              as? [String: Any]
        else { return .json("{}", status: 404) }
        detail["ministry"] = ministry
        guard let data = try? JSONSerialization.data(withJSONObject: detail),
              let text = String(bytes: data, encoding: .utf8)
        else { return .json("{}", status: 500) }
        return .json(text)
    }

    static var ministriesJSON: String {
        #"""
        [
          {"id": "bible-studies", "kind": "bibleStudy", "name": "Gatbo", "schedule": "Every week",
           "place": "Bacon, Sorsogon City",
           "summary": "We visit a community each week and study the Bible in their place.",
           "imageURL": "\#(photo(bible, width: 800))",
           "photos": ["\#(photo(bible))", "\#(photo(meal, width: 400))", "\#(photo(families, width: 400))"]},
          {"id": "community-2", "kind": "bibleStudy", "name": "San Isidro", "schedule": "Every week",
           "place": "Katorse, Sorsogon",
           "summary": "We visit a community each week and study the Bible in their place.",
           "photos": ["\#(photo(families))", "\#(photo(bible, width: 400))", "\#(photo(meal, width: 400))"]},
          {"id": "community-3", "kind": "bibleStudy", "name": "Cambulaga", "schedule": "Every week",
           "place": "Sorsogon City",
           "summary": "We visit a community each week and study the Bible in their place.",
           "photos": ["\#(photo(meal))", "\#(photo(families, width: 400))", "\#(photo(bible, width: 400))"]},
          {"id": "school-fund", "kind": "school", "name": "School fund", "schedule": "Every month",
           "summary": "Your gift pays school fees, jeepney fare and notebooks for kids in Gatbo and Bacon.",
           "imageURL": "\#(photo(13_040_204, width: 800))", "fund": {"kidsPaid": 12, "kidsGoal": 20}},
          {"id": "farming", "kind": "skill", "name": "Farming", "partner": "Bro. Jonathan & family",
           "summary": "Grow food for the family.", "imageURL": "\#(photo(7_658_774))"},
          {"id": "crochet", "kind": "skill", "name": "Crochet", "partner": "Studio_rae",
           "summary": "Make things to sell.", "imageURL": "\#(photo(3_945_638))"},
          {"id": "mental-health", "kind": "skill", "name": "Mental health awareness", "partner": "Love Project",
           "summary": "Know the signs, and where to get help.", "imageURL": "\#(photo(5_711_170))"}
        ]
        """#
    }
}
