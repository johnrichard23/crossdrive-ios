@testable import Crossdrive
import XCTest

final class OnboardingStoreTests: XCTestCase {
    private let suiteName = "OnboardingStoreTests"
    private let dana = SessionState.signedIn(AppUser(id: "dana-id"))
    private let sam = SessionState.signedIn(AppUser(id: "sam-id"))

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Device

    func testIsDone_WhenNothingStored_ShouldBeFalse() {
        // Arrange
        let store = OnboardingStore(defaults: defaults())

        // Act and Assert
        XCTAssertFalse(store.isDone(for: .signedOut))
        XCTAssertFalse(store.isDone(for: dana))
    }

    func testMarkDone_WhenSignedOut_ShouldSurviveANewStoreOnTheSameDefaults() {
        // Arrange
        OnboardingStore(defaults: defaults()).markDone(for: .signedOut)

        // Act
        let isDone = OnboardingStore(defaults: defaults()).isDone(for: .signedOut)

        // Assert
        XCTAssertTrue(isDone)
    }

    func testIsDone_WhenFinishedAsAGuest_ShouldBeDoneForEveryAccountToo() {
        // Arrange
        let store = OnboardingStore(defaults: defaults())
        store.markDone(for: .signedOut)

        // Act and Assert
        XCTAssertTrue(store.isDone(for: dana))
        XCTAssertTrue(store.isDone(for: sam))
    }

    // MARK: - Account

    func testIsDone_WhenFinishedSignedIn_ShouldBeDoneOnlyForThatAccount() {
        // Arrange
        let store = OnboardingStore(defaults: defaults())
        store.markDone(for: dana)

        // Act and Assert
        XCTAssertTrue(store.isDone(for: dana))
        XCTAssertFalse(store.isDone(for: sam))
        XCTAssertFalse(store.isDone(for: .signedOut))
    }

    func testIsDone_WhenAnAccountSignsOutAndBackIn_ShouldStillBeDone() {
        // Arrange
        let store = OnboardingStore(defaults: defaults())
        store.markDone(for: dana)

        // Act: signing out and back in is the same account on the same device.
        let afterSignOut = store.isDone(for: .signedOut)
        let afterSignIn = store.isDone(for: dana)

        // Assert
        XCTAssertFalse(afterSignOut)
        XCTAssertTrue(afterSignIn)
    }

    func testMarkDone_WhenSignedIn_ShouldNotWriteTheUserIDToDisk() {
        // Arrange
        let store = OnboardingStore(defaults: defaults())

        // Act
        store.markDone(for: dana)

        // Assert
        let stored = defaults().persistentDomain(forName: suiteName) ?? [:]
        XCTAssertFalse(stored.isEmpty)
        XCTAssertFalse(stored.keys.contains { $0.contains("dana-id") })
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
