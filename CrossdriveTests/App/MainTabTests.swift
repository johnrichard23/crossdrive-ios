@testable import Crossdrive
import XCTest

final class MainTabTests: XCTestCase {
    func testTitle_WhenListingEveryTab_ShouldBeHomeEventsMinistriesPrayProfileInOrder() {
        // Arrange / Act
        let titles = MainTab.allCases.map(\.title)

        // Assert
        XCTAssertEqual(titles, ["Home", "Events", "Ministries", "Pray", "Profile"])
    }

    func testIconName_WhenListingEveryTab_ShouldNameAnIconInTheAssetCatalog() {
        // Arrange / Act
        let missing = MainTab.allCases.filter { UIImage(named: $0.iconName) == nil }

        // Assert
        XCTAssertEqual(missing, [])
    }
}
