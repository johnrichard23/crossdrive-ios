@testable import Crossdrive
import DataLayer
import XCTest

private let ministriesJSON = """
[
  {"id": "a", "name": "Bible studies", "schedule": "Every week", "place": "Gatbo", "summary": "Study."},
  {"name": "No id"},
  {"id": "b", "name": "Kids' class"}
]
"""

@MainActor
final class MinistriesViewModelTests: XCTestCase {
    func testLoad_WhenServerReturnsMinistries_ShouldKeepTheReadableOnesInOrder() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json(ministriesJSON) }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state.value?.map(\.id), ["a", "b"])
        XCTAssertEqual(viewModel.state.value?.last?.summary, "")
    }

    func testLoad_WhenServerReturnsNothing_ShouldBeLoadedAndEmpty() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json("[]") }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .loaded([]))
    }

    func testLoad_WhenOffline_ShouldBeOffline() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in throw NetworkError.noConnection }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .offline)
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

    func testLoad_WhenAlreadyLoaded_ShouldNotAskAgain() async {
        // Arrange
        let (viewModel, client) = makeViewModel { _ in .json(ministriesJSON) }
        await viewModel.load()

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(client.requests.count, 1)
    }

    private func makeViewModel(
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
    ) -> (MinistriesViewModel, StubHTTPClient) {
        let client = StubHTTPClient(handler)
        return (MinistriesViewModel(api: MinistriesAPI(client: client)), client)
    }
}
