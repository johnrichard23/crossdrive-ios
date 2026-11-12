@testable import Crossdrive
import XCTest

@MainActor
final class NotificationPermissionViewModelTests: XCTestCase {
    func testRefresh_WhenTheUserAlreadyAllowedThem_ShouldBeAuthorized() async {
        // Arrange
        let viewModel =
            NotificationPermissionViewModel(push: FakePushRegistrar(current: .authorized))

        // Act
        await viewModel.refresh()

        // Assert
        XCTAssertEqual(viewModel.authorization, .authorized)
    }

    func testRefresh_WhenTheUserTurnedThemOffInSettings_ShouldBeDenied() async {
        // Arrange
        let viewModel = NotificationPermissionViewModel(push: FakePushRegistrar(current: .denied))

        // Act
        await viewModel.refresh()

        // Assert
        XCTAssertEqual(viewModel.authorization, .denied)
    }

    func testRequest_WhenTheUserAllows_ShouldBeAuthorizedAfterOnePrompt() async {
        // Arrange
        let push = FakePushRegistrar(answerToPrompt: .authorized)
        let viewModel = NotificationPermissionViewModel(push: push)

        // Act
        await viewModel.request()

        // Assert
        let prompts = await push.promptCount
        XCTAssertEqual(viewModel.authorization, .authorized)
        XCTAssertEqual(prompts, 1)
    }

    func testRequest_WhenTheUserRefuses_ShouldBeDenied() async {
        // Arrange
        let viewModel = NotificationPermissionViewModel(
            push: FakePushRegistrar(answerToPrompt: .denied)
        )

        // Act
        await viewModel.request()

        // Assert
        XCTAssertEqual(viewModel.authorization, .denied)
    }

    func testRequest_WhenAPromptIsAlreadyOpen_ShouldNotAskAgain() async {
        // Arrange: the system prompt is on screen.
        let started = Gate()
        let release = Gate()
        let prompts = Counter()
        let viewModel = NotificationPermissionViewModel(
            push: GatedPushRegistrar(started: started, release: release, prompts: prompts)
        )
        let first = Task { await viewModel.request() }
        await started.wait()

        // Act
        await viewModel.request()
        await release.open()
        await first.value

        // Assert
        XCTAssertEqual(prompts.next(), 2, "the prompt should have been shown exactly once")
        XCTAssertFalse(viewModel.isRequesting)
    }
}
