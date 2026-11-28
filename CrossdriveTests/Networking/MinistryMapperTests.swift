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

    func testModel_WhenAFundHasCosts_ShouldKeepOnlyTheReadableOnes() {
        // Arrange
        let peso = { (pesos: Int?) in EventDTO.MoneyDTO(
            amountMinor: pesos.map { $0 * 100 },
            currency: "PHP"
        ) }
        var input = dto(kind: "school")
        input.fund = .init(
            kidsPaid: 12,
            kidsGoal: 20,
            raised: peso(96000),
            goal: peso(160_000),
            costs: [
                .init(title: "School fees", amount: peso(450)),
                .init(title: "", amount: peso(250)),
                .init(title: "Notebooks", amount: peso(nil)),
                .init(title: "Free", amount: peso(0)),
            ]
        )

        // Act
        let fund = MinistryMapper().model(from: input)?.fund

        // Assert
        XCTAssertEqual(fund?.costs.map(\.title), ["School fees"])
        XCTAssertEqual(fund?.kidMonthMinor, 45000)
        XCTAssertEqual(fund?.toGo?.amountMinor, 6_400_000)
        XCTAssertEqual(fund?.fraction ?? 0, 0.6, accuracy: 0.0001)
    }

    func testModel_WhenAFundMixesCurrencies_ShouldDropWhatCantBeAdded() {
        // Arrange
        let money = { (pesos: Int, currency: String) in
            EventDTO.MoneyDTO(amountMinor: pesos * 100, currency: currency)
        }
        var mixedTotals = dto(kind: "school")
        mixedTotals.fund = .init(
            kidsPaid: 1,
            kidsGoal: 2,
            raised: money(96000, "PHP"),
            goal: money(3000, "USD")
        )
        var mixedCosts = dto(kind: "school")
        mixedCosts.fund = .init(kidsPaid: 1, kidsGoal: 2, goal: money(160_000, "PHP"), costs: [
            .init(title: "School fees", amount: money(450, "PHP")),
            .init(title: "Books", amount: money(5, "USD")),
        ])

        // Act
        let totals = MinistryMapper().model(from: mixedTotals)?.fund
        let costs = MinistryMapper().model(from: mixedCosts)?.fund

        // Assert
        XCTAssertNil(totals?.raised)
        XCTAssertNil(totals?.goal)
        XCTAssertEqual(costs?.costs.map(\.title), ["School fees"])
    }

    private func dto(kind: String? = nil) -> MinistryDTO {
        MinistryDTO(id: "m", name: "Ministry", kind: kind)
    }
}
