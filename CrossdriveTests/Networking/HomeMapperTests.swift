@testable import Crossdrive
import XCTest

final class HomeMapperTests: XCTestCase {
    private let mapper = HomeMapper()

    func testModel_WhenEveryPartIsThere_ShouldMapAllThree() {
        // Arrange
        let dto = HomeDTO(
            nextEvent: .init(id: "e", title: "Behia", startsAt: "2026-12-11T22:00:00Z"),
            prayerPoint: .init(id: "p", body: "Safe seas", prayedCount: 2),
            latestStory: .init(id: "s", title: "Kwento")
        )

        // Act
        let summary = mapper.model(from: dto)

        // Assert
        XCTAssertEqual(summary.nextEvent?.title, "Behia")
        XCTAssertEqual(summary.prayerPoint?.prayedCount, 2)
        XCTAssertEqual(summary.latestStory?.summary, "")
    }

    func testModel_WhenTheEventHasNoStartDate_ShouldDropItAndKeepTheRest() {
        // Arrange
        let dto = HomeDTO(
            nextEvent: .init(id: "e", title: "Behia"),
            prayerPoint: .init(id: "p", body: "Safe seas")
        )

        // Act
        let summary = mapper.model(from: dto)

        // Assert
        XCTAssertNil(summary.nextEvent)
        XCTAssertEqual(summary.prayerPoint?.id, "p")
    }

    func testModel_WhenEventStatusIsFull_ShouldMarkItClosed() {
        // Arrange
        let dto = HomeDTO(
            nextEvent: .init(
                id: "e",
                title: "Behia",
                startsAt: "2026-12-11T22:00:00Z",
                status: "full"
            )
        )

        // Act
        let summary = mapper.model(from: dto)

        // Assert
        XCTAssertEqual(summary.nextEvent?.isClosed, true)
    }

    func testModel_WhenNothingIsSent_ShouldBeEmpty() {
        // Act and Assert
        XCTAssertTrue(mapper.model(from: HomeDTO()).isEmpty)
    }
}
