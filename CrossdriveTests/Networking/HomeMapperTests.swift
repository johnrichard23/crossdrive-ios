@testable import Crossdrive
import XCTest

final class HomeMapperTests: XCTestCase {
    private let mapper = HomeMapper()

    private func dto(going: Bool = false, consent: Bool = true) throws -> HomeDTO {
        let json = SampleStub.homeJSON(going: going)
            .replacingOccurrences(of: "\"hasConsent\": true", with: "\"hasConsent\": \(consent)")
        return try JSONDecoder().decode(HomeDTO.self, from: Data(json.utf8))
    }

    func testModel_WhenTripAndStoryAreThere_ShouldMapBoth() throws {
        // Act
        let summary = try mapper.model(from: dto())

        // Assert
        XCTAssertEqual(summary.trip?.event.title, "Behia Mission Trip")
        XCTAssertEqual(summary.trip?.route?.origin, "Magallanes")
        XCTAssertEqual(summary.latestStory?.quote, "Salamat, Behia.")
    }

    func testModel_WhenGuest_ShouldNotCarryAMeetingPoint() throws {
        // Arrange
        var dto = try dto()
        dto.nextTrip?.meetup = .init(point: "Magallanes port", time: "5:30 AM")

        // Act
        let summary = mapper.model(from: dto)

        // Assert
        XCTAssertNil(summary.trip?.meetup)
        XCTAssertEqual(summary.trip?.bar, .register)
    }

    func testModel_WhenGoing_ShouldKeepTheMeetingPoint() throws {
        // Act
        let summary = try mapper.model(from: dto(going: true))

        // Assert
        XCTAssertEqual(summary.trip?.meetup?.point, "Magallanes port")
        XCTAssertEqual(summary.trip?.isGoing, true)
    }

    func testModel_WhenStoryHasNoConsent_ShouldDropTheStoryAndKeepTheTrip() throws {
        // Act
        let summary = try mapper.model(from: dto(consent: false))

        // Assert
        XCTAssertNil(summary.latestStory)
        XCTAssertNotNil(summary.trip)
    }

    func testModel_WhenFilmIsNotHTTPS_ShouldDropTheFilmLink() throws {
        // Arrange
        var dto = try dto()
        dto.latestStory?.filmURL = "http://example.com/film"

        // Act
        let summary = mapper.model(from: dto)

        // Assert
        XCTAssertNil(summary.latestStory?.filmURL)
    }

    func testModel_WhenNothingIsSent_ShouldBeEmpty() {
        // Act and Assert
        XCTAssertTrue(mapper.model(from: HomeDTO()).isEmpty)
    }
}
