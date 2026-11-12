@testable import Crossdrive
import DataLayer
import DesignSystem
import XCTest

private let twoItemsJSON = #"[{"id": "1", "title": "A"}, {"id": "2", "title": "B"}]"#

@MainActor
final class SampleListViewModelTests: XCTestCase {
    // MARK: - Loading

    func testLoad_WhenServerReturnsItems_ShouldBeLoaded() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json(twoItemsJSON) }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state.value?.map(\.id), ["1", "2"])
    }

    func testLoad_WhenServerReturnsNothing_ShouldBeLoadedAndEmpty() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json("[]") }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .loaded([]))
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
        let (viewModel, client) = makeViewModel { _ in .json(twoItemsJSON) }
        await viewModel.load()

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(client.requests.count, 1)
    }

    func testLoad_WhenForcedAfterLoading_ShouldAskAgain() async {
        // Arrange
        let (viewModel, client) = makeViewModel { _ in .json(twoItemsJSON) }
        await viewModel.load()

        // Act
        await viewModel.load(forceReload: true)

        // Assert
        XCTAssertEqual(client.requests.count, 2)
    }

    func testLoad_WhenRetriedAfterFailing_ShouldRecover() async {
        // Arrange
        let calls = Counter()
        let (viewModel, _) = makeViewModel { _ in
            calls.next() == 1 ? .json("{}", status: 500) : .json(twoItemsJSON)
        }
        await viewModel.load()

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state.value?.count, 2)
    }

    func testLoad_WhenARefreshFails_ShouldKeepTheContentAndShowAToast() async {
        // Arrange
        let calls = Counter()
        let (viewModel, _) = makeViewModel { _ in
            if calls.next() == 1 {
                return .json(twoItemsJSON)
            }
            throw NetworkError.noConnection
        }
        await viewModel.load()

        // Act
        await viewModel.load(forceReload: true)

        // Assert
        XCTAssertEqual(viewModel.state.value?.count, 2)
        XCTAssertEqual(viewModel.toast?.message, NetworkError.noConnection.userMessage)
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
                return .json(#"[{"id": "old"}]"#)
            }
            return .json(#"[{"id": "new"}]"#)
        }
        let first = Task { await viewModel.load() }
        await started.wait()

        // Act
        await viewModel.load(forceReload: true)
        await release.open()
        await first.value

        // Assert
        XCTAssertEqual(viewModel.state.value?.map(\.id), ["new"])
    }

    // MARK: - Favourites

    func testToggleFavorite_WhenServerAccepts_ShouldMarkTheItem() async {
        // Arrange
        let (viewModel, client) = makeViewModel { _ in .json(twoItemsJSON) }
        await viewModel.load()

        // Act
        await viewModel.toggleFavorite("1")

        // Assert
        XCTAssertEqual(viewModel.item(withID: "1")?.isFavorite, true)
        XCTAssertEqual(client.requests.last?.path, "items/1/favorite")
    }

    func testToggleFavorite_WhenServerRejects_ShouldRollBackAndShowAToast() async {
        // Arrange
        let (viewModel, _) = makeViewModel { endpoint in
            endpoint.method == .put ? .json("{}", status: 500) : .json(twoItemsJSON)
        }
        await viewModel.load()

        // Act
        await viewModel.toggleFavorite("1")

        // Assert
        XCTAssertEqual(viewModel.item(withID: "1")?.isFavorite, false)
        XCTAssertNotNil(viewModel.toast)
    }

    func testToggleFavorite_WhenTheSameItemIsAlreadyBeingSaved_ShouldSendOnlyOneRequest() async {
        // Arrange: the first save waits for the server.
        let started = Gate()
        let release = Gate()
        let (viewModel, client) = makeViewModel { endpoint in
            guard endpoint.method == .put else { return .json(twoItemsJSON) }
            await started.open()
            await release.wait()
            return .json("{}")
        }
        await viewModel.load()
        let first = Task { await viewModel.toggleFavorite("1") }
        await started.wait()

        // Act
        await viewModel.toggleFavorite("1")
        await release.open()
        await first.value

        // Assert
        XCTAssertEqual(client.requests.filter { $0.method == .put }.count, 1)
        XCTAssertEqual(viewModel.item(withID: "1")?.isFavorite, true)
    }

    func testToggleFavorite_WhenTheItemIsUnknown_ShouldSendNothing() async {
        // Arrange
        let (viewModel, client) = makeViewModel { _ in .json(twoItemsJSON) }
        await viewModel.load()

        // Act
        await viewModel.toggleFavorite("missing")

        // Assert
        XCTAssertEqual(client.requests.count, 1)
    }

    // MARK: - Helper

    private func makeViewModel(
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
    ) -> (SampleListViewModel, StubHTTPClient) {
        let client = StubHTTPClient(handler)
        return (SampleListViewModel(api: SampleAPI(client: client)), client)
    }
}
