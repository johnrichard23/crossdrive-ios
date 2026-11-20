@testable import Crossdrive
import DataLayer
import DesignSystem
import XCTest

private let homeJSON = SampleStub.homeJSON()

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testLoad_WhenServerReturnsHome_ShouldBeLoaded() async {
        // Arrange
        let (viewModel, _) = makeViewModel { _ in .json(homeJSON) }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state.value?.trip?.event.id, "behia")
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
        XCTAssertEqual(viewModel.state.value?.trip?.event.id, "behia")
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
                return .json(SampleStub.homeJSON().replacingOccurrences(of: "behia", with: "old"))
            }
            return .json(SampleStub.homeJSON().replacingOccurrences(of: "behia", with: "new"))
        }
        let first = Task { await viewModel.load() }
        await started.wait()

        // Act
        await viewModel.load(forceReload: true)
        await release.open()
        await first.value

        // Assert
        XCTAssertEqual(viewModel.state.value?.trip?.event.id, "new")
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
        XCTAssertEqual(viewModel.state.value?.trip?.event.id, "behia")
    }

    func testLoad_WhenMediaIsGiven_ShouldHoldTheLoadingStateUntilPhotosAreReady() async {
        // Arrange
        let release = Gate()
        let client = StubHTTPClient { _ in .json(homeJSON) }
        let viewModel = HomeViewModel(
            api: HomeAPI(client: client),
            eventsAPI: EventsAPI(client: client),
            imageLoader: FakeImageLoader(beforeReturning: { await release.wait() }),
            snapshotter: FakeSnapshotter(),
            mediaDeadline: { try? await Task.sleep(for: .seconds(60)) }
        )
        let media = HomeViewModel.MediaLayout(
            tripSize: CGSize(width: 10, height: 10),
            storySize: CGSize(width: 10, height: 10),
            scale: 1
        )

        // Act
        let task = Task { await viewModel.load(media: media) }
        await Task.yield()
        let whileWaiting = viewModel.state
        await release.open()
        await task.value

        // Assert
        XCTAssertEqual(whileWaiting, .loading)
        XCTAssertNotNil(viewModel.state.value)
        XCTAssertNotNil(viewModel.tripImage)
        XCTAssertNotNil(viewModel.storyImage)
    }

    func testLoad_WhenPhotosAreTooSlow_ShouldShowTheScreenAtTheDeadline() async {
        // Arrange
        let never = Gate()
        let client = StubHTTPClient { _ in .json(homeJSON) }
        let viewModel = HomeViewModel(
            api: HomeAPI(client: client),
            eventsAPI: EventsAPI(client: client),
            imageLoader: FakeImageLoader(beforeReturning: { await never.wait() }),
            snapshotter: FakeSnapshotter(),
            mediaDeadline: {}
        )
        let media = HomeViewModel.MediaLayout(
            tripSize: CGSize(width: 10, height: 10),
            storySize: CGSize(width: 10, height: 10),
            scale: 1
        )

        // Act
        let task = Task { await viewModel.load(media: media) }
        while viewModel.state.value == nil {
            await Task.yield()
        }
        task.cancel()

        // Assert
        XCTAssertNil(viewModel.tripImage)
        XCTAssertNotNil(viewModel.state.value)
    }

    func testRefreshCountdown_WhenTheDayChanges_ShouldUpdateTheNumber() async {
        // Arrange
        let clock = HomeTestClock(start: ISO8601DateFormatter()
            .date(from: "2026-11-20T02:00:00Z") ?? .now)
        let client = StubHTTPClient { _ in .json(homeJSON) }
        let viewModel = HomeViewModel(
            api: HomeAPI(client: client),
            eventsAPI: EventsAPI(client: client),
            imageLoader: FakeImageLoader(),
            snapshotter: FakeSnapshotter(),
            now: { clock.now }
        )
        await viewModel.load()
        let before = viewModel.countdown?.number

        // Act
        clock.advance(by: 24 * 3600)
        viewModel.refreshCountdown()

        // Assert
        XCTAssertEqual(before, "22")
        XCTAssertEqual(viewModel.countdown?.number, "21")
    }

    private func makeViewModel(
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
    ) -> (HomeViewModel, StubHTTPClient) {
        let client = StubHTTPClient(handler)
        let viewModel = HomeViewModel(
            api: HomeAPI(client: client),
            eventsAPI: EventsAPI(client: client),
            imageLoader: FakeImageLoader(),
            snapshotter: FakeSnapshotter(),
            mediaDeadline: { try? await Task.sleep(for: .seconds(60)) }
        )
        return (viewModel, client)
    }
}

private final class HomeTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(start: Date) {
        current = start
    }

    var now: Date {
        lock.withLock { current }
    }

    func advance(by seconds: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(seconds) }
    }
}

@MainActor
final class HomeDetailModelsTests: XCTestCase {
    func testDetailViewModel_WhenAskedTwiceForOneTrip_ShouldReturnTheSameOne() {
        // Arrange
        let viewModel = makeViewModel()

        // Act
        let first = viewModel.detailViewModel(for: "behia")
        let second = viewModel.detailViewModel(for: "behia")

        // Assert
        XCTAssertTrue(first === second)
    }

    func testOpenTripsChanged_WhenATripLeavesTheStack_ShouldFreeItsViewModel() {
        // Arrange
        let viewModel = makeViewModel()
        weak var weakDetail: EventDetailViewModel?
        autoreleasepool { weakDetail = viewModel.detailViewModel(for: "behia") }

        // Act
        viewModel.openTripsChanged(to: [])

        // Assert
        XCTAssertNil(weakDetail)
    }

    private func makeViewModel() -> HomeViewModel {
        let client = StubHTTPClient { _ in .json("{}") }
        return HomeViewModel(
            api: HomeAPI(client: client),
            eventsAPI: EventsAPI(client: client),
            imageLoader: FakeImageLoader(),
            snapshotter: FakeSnapshotter()
        )
    }
}
