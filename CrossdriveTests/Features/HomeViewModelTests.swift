@testable import Crossdrive
import DataLayer
import DesignSystem
import XCTest

private let homeJSON = #"{"prayerPoint": {"id": "p1", "body": "Safe seas.", "prayedCount": 3}}"#

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testLoad_WhenServerReturnsHome_ShouldBeLoaded() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json(homeJSON) }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state.value?.prayerPoint?.id, "p1")
    }

    func testLoad_WhenServerReturnsNothing_ShouldBeLoadedAndEmpty() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json("{}") }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .loaded(HomeSummary()))
    }

    func testLoad_WhenServerFails_ShouldBeFailedWithPlainMessage() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json("{}", status: 500) }

        // Act
        await viewModel.load()

        // Assert
        let expected = NetworkError.server(status: 500, message: nil).userMessage
        XCTAssertEqual(viewModel.state, .failed(expected))
    }

    func testLoad_WhenOffline_ShouldBeOffline() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in throw NetworkError.noConnection }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .offline)
    }

    func testLoad_WhenAlreadyLoaded_ShouldNotAskAgain() async {
        // Arrange
        let (viewModel, client) = makeViewModel { _ in .json(homeJSON) }
        await viewModel.load()

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(client.requests.count, 1)
    }

    func testLoad_WhenRefreshFails_ShouldKeepTheContentAndShowAToast() async {
        // Arrange
        let calls = Counter()
        let (viewModel, _) = makeViewModel { _ in
            if calls.next() == 1 {
                return .json(homeJSON)
            }
            throw NetworkError.noConnection
        }
        await viewModel.load()

        // Act
        await viewModel.load(forceReload: true)

        // Assert
        XCTAssertEqual(viewModel.state.value?.prayerPoint?.id, "p1")
        XCTAssertNotNil(viewModel.toast)
    }

    func testLoad_WhenAnOlderLoadFinishesLast_ShouldKeepTheNewerResult() async {
        // Arrange: the first request waits; the second answers at once.
        let started = Gate()
        let release = Gate()
        let calls = Counter()
        let (viewModel, _) = makeViewModel { _ in
            if calls.next() == 1 {
                await started.open()
                await release.wait()
                return .json(#"{"prayerPoint": {"id": "old", "body": "Old"}}"#)
            }
            return .json(#"{"prayerPoint": {"id": "new", "body": "New"}}"#)
        }
        let first = Task { await viewModel.load() }
        await started.wait()

        // Act
        await viewModel.load(forceReload: true)
        await release.open()
        await first.value

        // Assert
        XCTAssertEqual(viewModel.state.value?.prayerPoint?.id, "new")
    }

    func testConnectionRestored_WhenHomeFailedOffline_ShouldLoadItAgain() async {
        // Arrange
        let calls = Counter()
        let (viewModel, _) = makeViewModel { _ in
            if calls.next() == 1 {
                throw NetworkError.noConnection
            }
            return .json(homeJSON)
        }
        await viewModel.load()

        // Act
        await viewModel.connectionRestored()

        // Assert
        XCTAssertEqual(viewModel.state.value?.prayerPoint?.id, "p1")
    }

    private func makeViewModel(
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
    ) -> (HomeViewModel, StubHTTPClient) {
        let client = StubHTTPClient(handler)
        return (HomeViewModel(api: HomeAPI(client: client)), client)
    }
}
