@testable import Crossdrive
import XCTest

final class MinistrySectionsTests: XCTestCase {
    func testSections_WhenKindsAreMixed_ShouldGroupThemInAFixedOrder() {
        // Arrange: the server's order mixes the kinds.
        let ministries = [
            ministry("farming", .skill),
            ministry("gatbo", .bibleStudy),
            ministry("fund", .school),
            ministry("bacon", .bibleStudy),
            ministry("kids", .other),
        ]

        // Act
        let sections = MinistrySection.sections(from: ministries, showing: nil)

        // Assert
        XCTAssertEqual(sections.map(\.kind), [.bibleStudy, .school, .skill, .other])
        XCTAssertEqual(sections.first?.ministries.map(\.id), ["gatbo", "bacon"])
    }

    func testSections_WhenAKindIsPicked_ShouldShowOnlyThatKind() {
        // Arrange
        let ministries = [ministry("gatbo", .bibleStudy), ministry("farming", .skill)]

        // Act
        let sections = MinistrySection.sections(from: ministries, showing: .skill)

        // Assert
        XCTAssertEqual(sections.map(\.kind), [.skill])
    }

    func testKinds_WhenSomeKindsAreMissing_ShouldOfferOnlyTheOnesPresent() {
        // Arrange
        let ministries = [ministry("farming", .skill), ministry("gatbo", .bibleStudy)]

        // Act
        let kinds = MinistrySection.kinds(in: ministries)

        // Assert
        XCTAssertEqual(kinds, [.bibleStudy, .skill])
    }

    func testSubtitle_ForBibleStudies_ShouldCountThePlaces() {
        // Arrange
        let cases: [(count: Int, expected: String?)] = [
            (3, "Every week, in 3 places."),
            (1, nil),
        ]

        for item in cases {
            let ministries = (0 ..< item.count).map { ministry("b\($0)", .bibleStudy) }

            // Act
            let section = MinistrySection.sections(from: ministries, showing: nil).first

            // Assert
            XCTAssertEqual(section?.subtitle, item.expected, "\(item.count)")
        }
    }

    func testSubtitle_WhenCommunitiesMeetOnDifferentDays_ShouldOnlyCountThePlaces() {
        // Arrange: one community meets on Sundays instead.
        var sunday = ministry("b2", .bibleStudy)
        sunday.schedule = "Every Sunday"
        let ministries = [ministry("b1", .bibleStudy), sunday]

        // Act
        let section = MinistrySection.sections(from: ministries, showing: nil).first

        // Assert
        XCTAssertEqual(section?.subtitle, "In 2 places.")
    }

    private func ministry(_ id: String, _ kind: Ministry.Kind) -> Ministry {
        Ministry(
            id: id,
            name: id,
            schedule: "Every week",
            place: nil,
            summary: "",
            imageURL: nil,
            kind: kind
        )
    }
}
