@testable import Crossdrive
import UIKit
import XCTest

final class ThemeFontsTests: XCTestCase {
    func testBundledFonts_WhenLoadedByTheNamesTheThemeUses_ShouldAllExist() {
        // Arrange: the names in `Theme.crossdrive`'s typeface.
        let names = [
            "DMSans-Regular", "DMSans-Medium", "DMSans-SemiBold",
            "Outfit-SemiBold", "Outfit-Bold",
        ]

        // Act
        let missing = names.filter { UIFont(name: $0, size: 17) == nil }

        // Assert
        XCTAssertEqual(missing, [], "Add the font file to Resources/Fonts and to UIAppFonts.")
    }
}
