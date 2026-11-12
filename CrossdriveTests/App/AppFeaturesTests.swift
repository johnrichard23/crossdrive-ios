@testable import Crossdrive
import XCTest

final class AppFeaturesTests: XCTestCase {
    private let suiteName = "AppFeaturesTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testInit_WhenNothingIsSet_ShouldBeGuestFirstWithoutOnboarding() {
        // Act
        let features = AppFeatures()

        // Assert
        XCTAssertEqual(features.authentication, .optional)
        XCTAssertFalse(features.onboarding)
        XCTAssertEqual(features.onboardingPlacement, .afterSignIn)
    }

    func testApplyOverrides_WhenNoArgumentsAreGiven_ShouldChangeNothing() {
        // Arrange
        var features = AppFeatures(authentication: .required, onboarding: true)

        // Act
        features.applyOverrides(defaults())

        // Assert
        XCTAssertEqual(features, AppFeatures(authentication: .required, onboarding: true))
    }

    func testApplyOverrides_WhenArgumentsAreGiven_ShouldChangeEachSetting() {
        // Arrange
        let defaults = defaults()
        defaults.set("required", forKey: "feature-auth")
        defaults.set("on", forKey: "feature-onboarding")
        defaults.set("beforeSignIn", forKey: "feature-onboarding-placement")
        var features = AppFeatures(authentication: .none, onboarding: false)

        // Act
        features.applyOverrides(defaults)

        // Assert
        XCTAssertEqual(features.authentication, .required)
        XCTAssertTrue(features.onboarding)
        XCTAssertEqual(features.onboardingPlacement, .beforeSignIn)
    }

    func testApplyOverrides_WhenAValueIsNotRecognised_ShouldIgnoreIt() {
        // Arrange
        let defaults = defaults()
        defaults.set("sometimes", forKey: "feature-auth")
        defaults.set("maybe", forKey: "feature-onboarding")
        var features = AppFeatures(authentication: .required, onboarding: true)

        // Act
        features.applyOverrides(defaults)

        // Assert
        XCTAssertEqual(features.authentication, .required)
        XCTAssertTrue(features.onboarding)
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
