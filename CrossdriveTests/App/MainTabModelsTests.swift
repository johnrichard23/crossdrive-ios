@testable import Crossdrive
import XCTest

@MainActor
final class MainTabModelsTests: XCTestCase {
    func testRead_WhenAskedTwice_ShouldReturnTheSameViewModel() {
        // Arrange
        let models = MainTabModels(container: .preview())

        // Act
        let first = models.events
        let second = models.events

        // Assert
        XCTAssertTrue(first === second)
        XCTAssertTrue(models.home === models.home)
        XCTAssertTrue(models.ministries === models.ministries)
    }

    func testModels_WhenTheyAreFreed_ShouldFreeTheirViewModels() {
        // Arrange
        weak var weakHome: HomeViewModel?
        weak var weakEvents: EventsViewModel?
        weak var weakMinistries: MinistriesViewModel?

        // Act
        autoreleasepool {
            let models = MainTabModels(container: .preview())
            weakHome = models.home
            weakEvents = models.events
            weakMinistries = models.ministries
        }

        // Assert
        XCTAssertNil(weakHome)
        XCTAssertNil(weakEvents)
        XCTAssertNil(weakMinistries)
    }
}
