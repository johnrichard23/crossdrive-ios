@testable import Crossdrive
import XCTest

final class FeatureFlagsTests: XCTestCase {
    private let suiteName = "FeatureFlagsTests"
    private let onFlag = FeatureFlag(key: "on-by-default", defaultValue: true)
    private let offFlag = FeatureFlag(key: "off-by-default", defaultValue: false)

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testIsEnabled_WhenNothingOverridesIt_ShouldUseTheDefault() {
        // Arrange
        let flags = LocalFeatureFlags(defaults: defaults())

        // Act and Assert
        XCTAssertTrue(flags.isEnabled(onFlag))
        XCTAssertFalse(flags.isEnabled(offFlag))
    }

    func testIsEnabled_WhenOverridden_ShouldUseTheOverrideInBothDirections() {
        // Arrange
        let flags = LocalFeatureFlags(defaults: defaults())

        // Act
        flags.setOverride(false, for: onFlag)
        flags.setOverride(true, for: offFlag)

        // Assert
        XCTAssertFalse(flags.isEnabled(onFlag))
        XCTAssertTrue(flags.isEnabled(offFlag))
    }

    func testSetOverride_WhenRemoved_ShouldGoBackToTheDefault() {
        // Arrange
        let flags = LocalFeatureFlags(defaults: defaults())
        flags.setOverride(false, for: onFlag)

        // Act
        flags.setOverride(nil, for: onFlag)

        // Assert
        XCTAssertTrue(flags.isEnabled(onFlag))
    }

    func testIsEnabled_WhenOverridesAreIgnored_ShouldUseTheDefault() {
        // Arrange: previews pass no defaults at all.
        defaults().set(false, forKey: "flag.on-by-default")
        let flags = LocalFeatureFlags(defaults: nil)

        // Act and Assert
        XCTAssertTrue(flags.isEnabled(onFlag))
    }

    func testAll_WhenListed_ShouldIncludeTheFavoritesFlag() {
        // Act and Assert
        XCTAssertTrue(FeatureFlag.all.contains(.favorites))
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
