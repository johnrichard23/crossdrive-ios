@testable import Crossdrive
import XCTest

final class StubAPIFlagTests: XCTestCase {
    private let suiteName = "StubAPIFlagTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testWantsStubAPI_WhenTheBareLaunchArgumentIsGiven_ShouldBeTrue() {
        // Arrange: what the Xcode scheme passes.
        let arguments = ["/path/to/Crossdrive", "-stub-api"]

        // Act
        let wants = CrossdriveApp.wantsStubAPI(arguments: arguments, defaults: defaults())

        // Assert
        XCTAssertTrue(wants)
    }

    func testWantsStubAPI_WhenTheDefaultIsSet_ShouldBeTrue() {
        // Arrange: `defaults write <bundle id> stub-api -bool YES`.
        defaults().set(true, forKey: "stub-api")

        // Act
        let wants = CrossdriveApp.wantsStubAPI(
            arguments: ["/path/to/Crossdrive"],
            defaults: defaults()
        )

        // Assert
        XCTAssertTrue(wants)
    }

    func testWantsStubAPI_WhenNeitherIsSet_ShouldBeFalse() {
        // Act
        let wants = CrossdriveApp.wantsStubAPI(
            arguments: ["/path/to/Crossdrive"],
            defaults: defaults()
        )

        // Assert
        XCTAssertFalse(wants)
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
