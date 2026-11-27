@testable import Crossdrive
import XCTest

final class MinistryMapperTests: XCTestCase {
    func testModel_WhenKindIsUnknownOrMissing_ShouldBeOther() {
        // Arrange
        let cases: [(kind: String?, expected: Ministry.Kind)] = [
            ("bibleStudy", .bibleStudy),
            ("school", .school),
            ("skill", .skill),
            ("choir", .other),
            (nil, .other),
        ]

        for item in cases {
            // Act
            let model = MinistryMapper().model(from: dto(kind: item.kind))

            // Assert
            XCTAssertEqual(model?.kind, item.expected, item.kind ?? "nil")
        }
    }

    func testModel_WhenThereAreNoPhotos_ShouldUseTheMainImage() {
        // Arrange
        var noPhotos = dto()
        noPhotos.imageURL = "https://example.com/main.jpg"
        var withPhotos = noPhotos
        withPhotos.photos = ["https://example.com/a.jpg", "not a url", "https://example.com/b.jpg"]

        // Act
        let fallback = MinistryMapper().model(from: noPhotos)?.photoURLs
        let photos = MinistryMapper().model(from: withPhotos)?.photoURLs

        // Assert
        XCTAssertEqual(fallback?.map(\.lastPathComponent), ["main.jpg"])
        XCTAssertEqual(photos?.map(\.lastPathComponent), ["a.jpg", "b.jpg"])
    }

    func testModel_ForEachFund_ShouldKeepOnlyAReadableGoal() {
        // Arrange
        let cases: [(fund: MinistryDTO.FundDTO?, expected: Ministry.Fund?)] = [
            (.init(kidsPaid: 12, kidsGoal: 20), .init(kidsPaid: 12, kidsGoal: 20)),
            (.init(kidsPaid: 25, kidsGoal: 20), .init(kidsPaid: 20, kidsGoal: 20)),
            (.init(kidsPaid: nil, kidsGoal: 20), .init(kidsPaid: 0, kidsGoal: 20)),
            (.init(kidsPaid: 3, kidsGoal: 0), nil),
            (.init(kidsPaid: 3, kidsGoal: nil), nil),
            (nil, nil),
        ]

        for (index, item) in cases.enumerated() {
            var input = dto(kind: "school")
            input.fund = item.fund

            // Act
            let model = MinistryMapper().model(from: input)

            // Assert
            XCTAssertEqual(model?.fund, item.expected, "case \(index)")
        }
    }

    private func dto(kind: String? = nil) -> MinistryDTO {
        MinistryDTO(id: "m", name: "Ministry", kind: kind)
    }
}
