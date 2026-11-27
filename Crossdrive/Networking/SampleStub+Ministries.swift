import Foundation

/// The canned `GET /ministries` reply: three Bible-study communities, the
/// school fund and three skills programs. Bracketed names are still to come
/// from the team.
extension SampleStub {
    private static func photo(_ id: Int, width: Int = 600) -> String {
        "https://images.pexels.com/photos/\(id)/pexels-photo-\(id).jpeg?auto=compress&w=\(width)"
    }

    private static let bible = 13_011_294
    private static let meal = 38_186_695
    private static let families = 16_934_870

    static var ministriesJSON: String {
        #"""
        [
          {"id": "bible-studies", "kind": "bibleStudy", "name": "Gatbo", "schedule": "Every week",
           "place": "Bacon, Sorsogon City",
           "summary": "We visit a community each week and study the Bible in their place.",
           "imageURL": "\#(photo(bible, width: 800))",
           "photos": ["\#(photo(bible))", "\#(photo(meal, width: 400))", "\#(photo(families, width: 400))"]},
          {"id": "community-2", "kind": "bibleStudy", "name": "[Community 2]", "schedule": "Every week",
           "place": "[Town, province]",
           "summary": "We visit a community each week and study the Bible in their place.",
           "photos": ["\#(photo(families))", "\#(photo(bible, width: 400))", "\#(photo(meal, width: 400))"]},
          {"id": "community-3", "kind": "bibleStudy", "name": "[Community 3]", "schedule": "Every week",
           "place": "[Town, province]",
           "summary": "We visit a community each week and study the Bible in their place.",
           "photos": ["\#(photo(meal))", "\#(photo(families, width: 400))", "\#(photo(bible, width: 400))"]},
          {"id": "school-fund", "kind": "school", "name": "School fund", "schedule": "Every month",
           "summary": "Your gift pays school fees, jeepney fare and notebooks for kids in Gatbo and Bacon.",
           "imageURL": "\#(photo(13_040_204, width: 800))", "fund": {"kidsPaid": 12, "kidsGoal": 20}},
          {"id": "farming", "kind": "skill", "name": "Farming", "partner": "[Partner name]",
           "summary": "Grow food for the family.", "imageURL": "\#(photo(7_658_774))"},
          {"id": "crochet", "kind": "skill", "name": "Crochet", "partner": "[Partner name]",
           "summary": "Make things to sell.", "imageURL": "\#(photo(3_945_638))"},
          {"id": "mental-health", "kind": "skill", "name": "Mental health awareness", "partner": "[Partner name]",
           "summary": "Know the signs, and where to get help.", "imageURL": "\#(photo(5_711_170))"}
        ]
        """#
    }
}
