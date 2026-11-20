@testable import Crossdrive
import DataLayer
import UIKit
import XCTest

private let mapJSON = """
{
  "event": {"id": "e1", "title": "Behia", "startsAt": "2026-12-11T22:00:00Z"},
  "location": {"name": "Island", "latitude": 12.8, "longitude": 123.9}
}
"""

private let photoJSON = """
{
  "event": {"id": "e1", "title": "Behia", "startsAt": "2026-12-11T22:00:00Z",
            "heroImageURL": "https://example.com/hero.jpg"}
}
"""

private let media = EventDetailViewModel.MediaLayout(
    heroSize: CGSize(width: 390, height: 340),
    mapSize: CGSize(width: 358, height: 210),
    scale: 3,
    isDark: false
)

@MainActor
final class EventDetailMapTests: XCTestCase {
    func testLoadMap_WhenCalledTwiceWithTheSameSize_ShouldDrawOnce() async {
        // Arrange
        let snapshotter = FakeSnapshotter()
        let viewModel = await loadedViewModel(snapshotter)
        let size = CGSize(width: 358, height: 210)

        // Act
        await viewModel.loadMap(size: size, scale: 3, isDark: false)
        await viewModel.loadMap(size: size, scale: 3, isDark: false)

        // Assert
        XCTAssertEqual(snapshotter.count, 1)
        XCTAssertNotNil(viewModel.mapImage)
    }

    func testLoadMap_WhenDarkModeChanges_ShouldDrawAgain() async {
        // Arrange
        let snapshotter = FakeSnapshotter()
        let viewModel = await loadedViewModel(snapshotter)
        let size = CGSize(width: 358, height: 210)

        // Act
        await viewModel.loadMap(size: size, scale: 3, isDark: false)
        await viewModel.loadMap(size: size, scale: 3, isDark: true)

        // Assert
        XCTAssertEqual(snapshotter.count, 2)
    }

    func testLoadMap_WhenSizeIsNotKnownYet_ShouldNotDraw() async {
        // Arrange
        let snapshotter = FakeSnapshotter()
        let viewModel = await loadedViewModel(snapshotter)

        // Act
        await viewModel.loadMap(size: .zero, scale: 3, isDark: false)

        // Assert
        XCTAssertEqual(snapshotter.count, 0)
        XCTAssertNil(viewModel.mapImage)
    }

    func testLoadMap_WhenTheTripHasNoLocation_ShouldNotDraw() async {
        // Arrange
        let snapshotter = FakeSnapshotter()
        let viewModel = EventDetailViewModel(
            api: EventsAPI(client: StubHTTPClient { _ in
                .json(#"{"event": {"id": "e1", "title": "T", "startsAt": "2026-12-11T22:00:00Z"}}"#)
            }),
            eventID: "e1",
            imageLoader: FakeImageLoader(),
            snapshotter: snapshotter
        )
        await viewModel.load()

        // Act
        await viewModel.loadMap(size: CGSize(width: 100, height: 100), scale: 2, isDark: false)

        // Assert
        XCTAssertEqual(snapshotter.count, 0)
    }

    func testViewModel_WhenTheScreenIsLeft_ShouldBeFreed() async {
        // Arrange
        weak var weakViewModel: EventDetailViewModel?
        do {
            let viewModel = await loadedViewModel(FakeSnapshotter())
            await viewModel.loadMap(size: CGSize(width: 100, height: 100), scale: 2, isDark: false)
            weakViewModel = viewModel
        }

        // Assert
        XCTAssertNil(weakViewModel)
    }

    func testLoad_WithMedia_ShouldStayLoadingUntilThePhotoIsReady() async {
        // Arrange
        let started = Gate()
        let release = Gate()
        let viewModel = photoViewModel(
            deadline: { try? await Task.sleep(for: .seconds(3600)) },
            beforeReturning: {
                await started.open()
                await release.wait()
            }
        )

        // Act
        let loading = Task { await viewModel.load(media: media) }
        await started.wait()
        let wasLoading = viewModel.state.value == nil
        await release.open()
        await loading.value

        // Assert
        XCTAssertTrue(wasLoading)
        XCTAssertNotNil(viewModel.state.value)
        XCTAssertNotNil(viewModel.heroImage)
    }

    @available(iOS 26.0, *)
    func testLoad_WhenThePhotoIsSlowerThanTheDeadline_ShouldShowTheScreenAnyway() async {
        // Arrange
        let release = Gate()
        let viewModel = photoViewModel(
            deadline: {},
            beforeReturning: { await release.wait() }
        )

        // Act
        let loading = Task { await viewModel.load(media: media) }
        for await isShown in Observations({ viewModel.state.value != nil }) where isShown {
            break
        }
        let hadNoPhotoYet = viewModel.heroImage == nil
        await release.open()
        await loading.value

        // Assert
        XCTAssertTrue(hadNoPhotoYet)
        XCTAssertNotNil(viewModel.heroImage)
    }

    func testLoad_WithMedia_ShouldDrawTheMapBeforeShowing() async {
        // Arrange
        let snapshotter = FakeSnapshotter()
        let viewModel = EventDetailViewModel(
            api: EventsAPI(client: StubHTTPClient { _ in .json(mapJSON) }),
            eventID: "e1",
            imageLoader: FakeImageLoader(),
            snapshotter: snapshotter
        )

        // Act
        await viewModel.load(media: media)

        // Assert
        XCTAssertNotNil(viewModel.state.value)
        XCTAssertNotNil(viewModel.mapImage)
        XCTAssertEqual(snapshotter.count, 1)
    }

    private func photoViewModel(
        deadline: @escaping @Sendable () async -> Void,
        beforeReturning: @escaping @Sendable () async -> Void
    ) -> EventDetailViewModel {
        EventDetailViewModel(
            api: EventsAPI(client: StubHTTPClient { _ in .json(photoJSON) }),
            eventID: "e1",
            imageLoader: FakeImageLoader(beforeReturning: beforeReturning),
            snapshotter: FakeSnapshotter(),
            mediaDeadline: deadline
        )
    }

    private func loadedViewModel(_ snapshotter: FakeSnapshotter) async -> EventDetailViewModel {
        let viewModel = EventDetailViewModel(
            api: EventsAPI(client: StubHTTPClient { _ in .json(mapJSON) }),
            eventID: "e1",
            imageLoader: FakeImageLoader(),
            snapshotter: snapshotter
        )
        await viewModel.load()
        return viewModel
    }
}
