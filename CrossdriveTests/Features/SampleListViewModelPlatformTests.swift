@testable import Crossdrive
import DataLayer
import XCTest

/// How the sample screen uses the platform services.
@MainActor
final class SampleListViewModelPlatformTests: XCTestCase {
    func testConnectionRestored_WhenTheListFailedOffline_ShouldLoadItAgain() async {
        // Arrange
        let calls = Counter()
        let (viewModel, _) = makeViewModel { _ in
            if calls.next() == 1 {
                throw NetworkError.noConnection
            }
            return .json(#"[{"id": "1", "title": "A"}]"#)
        }
        await viewModel.load()

        // Act
        await viewModel.connectionRestored()

        // Assert
        XCTAssertEqual(viewModel.state.value?.count, 1)
    }

    func testConnectionRestored_WhenTheListIsLoaded_ShouldNotAskAgain() async {
        // Arrange
        let (viewModel, client) = makeViewModel { _ in .json("[]") }
        await viewModel.load()

        // Act
        await viewModel.connectionRestored()

        // Assert
        XCTAssertEqual(client.requests.count, 1)
    }

    func testLoad_WhenTheReplyCannotBeRead_ShouldReportItAsABug() async {
        // Arrange
        let reporter = RecordingCrashReporter()
        let (viewModel, _) = makeViewModel(reporter: reporter) { _ in .json("not json") }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(reporter.errors.values, ["Loading items"])
        XCTAssertEqual(viewModel.state, .failed(NetworkError.decoding("").userMessage))
    }

    func testLoad_WhenTheUserIsOffline_ShouldNotReportAnything() async {
        // Arrange
        let reporter = RecordingCrashReporter()
        let (viewModel, _) = makeViewModel(reporter: reporter) { _ in
            throw NetworkError.noConnection
        }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertTrue(reporter.errors.values.isEmpty)
    }

    private func makeViewModel(
        reporter: any CrashReporter = NoCrashReporter(),
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
    ) -> (SampleListViewModel, StubHTTPClient) {
        let client = StubHTTPClient(handler)
        return (SampleListViewModel(api: SampleAPI(client: client), reporter: reporter), client)
    }
}
