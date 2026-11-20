import DataLayer
import Observation
import UIKit

/// The event detail screen's view model, shaped like `SampleListViewModel`.
@Observable @MainActor
final class EventDetailViewModel {
    private(set) var state: LoadState<EventDetail> = .loading
    /// The event is gone or was taken down (the server said not found).
    private(set) var isUnavailable = false
    /// The still map of the place; `nil` until it is drawn or if it cannot be.
    private(set) var mapImage: UIImage?
    /// The hero photo, decoded at the size it is shown; `nil` until it has loaded.
    private(set) var heroImage: UIImage?

    /// Where the photo and the map will be shown, so they can be made ready
    /// before the screen appears.
    struct MediaLayout: Equatable, Sendable {
        var heroSize: CGSize
        var mapSize: CGSize
        var scale: CGFloat
        var isDark: Bool
    }

    private let api: EventsAPI
    private let reporter: any CrashReporter
    private let snapshotter: any MapSnapshotting
    private let imageLoader: any ImageLoading
    private let mediaDeadline: @Sendable () async -> Void
    private let eventID: Event.ID
    private var loadToken = 0
    private var mapKey: MapKey?

    /// What a drawn map was made for. The size is rounded to whole points, so a
    /// fraction of a point of layout difference never draws the map a second time.
    private struct MapKey: Equatable {
        var size: CGSize
        var scale: CGFloat
        var isDark: Bool

        init(size: CGSize, scale: CGFloat, isDark: Bool) {
            self.size = CGSize(width: size.width.rounded(), height: size.height.rounded())
            self.scale = scale
            self.isDark = isDark
        }
    }

    init(
        api: EventsAPI,
        eventID: Event.ID,
        imageLoader: any ImageLoading,
        snapshotter: any MapSnapshotting,
        reporter: any CrashReporter = NoCrashReporter(),
        mediaDeadline: @escaping @Sendable () async -> Void = {
            try? await Task.sleep(for: .seconds(3))
        }
    ) {
        self.api = api
        self.eventID = eventID
        self.reporter = reporter
        self.snapshotter = snapshotter
        self.imageLoader = imageLoader
        self.mediaDeadline = mediaDeadline
    }

    /// Loads the trip. With `media`, the loading state stays up until the photo
    /// and the map are ready too, so nothing pops in after the screen appears.
    /// A slow network never holds it longer than `mediaDeadline` (3 seconds by
    /// default; a test passes its own so it never waits on a clock): then the
    /// screen shows and the rest fills in.
    func load(media: MediaLayout? = nil, forceReload: Bool = false) async {
        if case .loaded = state, !forceReload {
            return
        }

        loadToken += 1
        let token = loadToken
        if state.value == nil {
            state = .loading
        }
        isUnavailable = false

        do {
            let detail = try await api.event(id: eventID)
            guard token == loadToken else { return }
            if let media {
                await revealWhenMediaIsReady(detail, media: media, token: token)
            } else {
                state = .loaded(detail)
            }
        } catch {
            guard token == loadToken, !Self.isCancellation(error) else { return }
            report(error)
            if (error as? NetworkError)?.statusCode == 404 {
                isUnavailable = true
                state = .failed(error.userMessage)
            } else {
                state = error.isOffline ? .offline : .failed(error.userMessage)
            }
        }
    }

    /// Redraws the map when the size, the screen scale or light and dark
    /// change. It stops if the caller's task is cancelled (the person left).
    func loadMap(size: CGSize, scale: CGFloat, isDark: Bool) async {
        guard let location = state.value?.location else { return }
        await drawMap(of: location, key: MapKey(size: size, scale: scale, isDark: isDark))
    }

    /// The device is back online: retry what failed because it wasn't.
    func connectionRestored(media: MediaLayout? = nil) async {
        switch state {
        case .offline, .failed: await load(media: media)
        case .loading, .loaded: break
        }
    }

    // MARK: - Media

    /// Waits for the photo and the map together, all inside the caller's task,
    /// so leaving the screen cancels every part of it.
    private func revealWhenMediaIsReady(
        _ detail: EventDetail,
        media: MediaLayout,
        token: Int
    ) async {
        let imageLoader = imageLoader
        let deadline = mediaDeadline
        await withTaskGroup(of: Bool.self) { group in
            var waitingFor = 0
            if let url = detail.event.heroImageURL {
                waitingFor += 1
                let pixels = ImageDownsampler.maxPixels(for: media.heroSize, scale: media.scale)
                group.addTask {
                    let image = await imageLoader.image(for: url, maxPixels: pixels)
                    await self.showHero(image)
                    return true
                }
            }
            if let location = detail.location {
                waitingFor += 1
                let key = MapKey(size: media.mapSize, scale: media.scale, isDark: media.isDark)
                group.addTask { await self.drawMap(of: location, key: key); return true }
            }
            guard waitingFor > 0 else {
                reveal(detail, token: token)
                return
            }
            group.addTask {
                await deadline()
                return false
            }
            for await isMedia in group {
                if isMedia {
                    waitingFor -= 1
                    if waitingFor == 0 {
                        reveal(detail, token: token)
                        group.cancelAll()
                    }
                } else {
                    // Too slow: show the screen now; the photo and map keep loading.
                    reveal(detail, token: token)
                }
            }
        }
    }

    private func showHero(_ image: UIImage?) {
        if let image {
            heroImage = image
        }
    }

    private func reveal(_ detail: EventDetail, token: Int) {
        guard token == loadToken, state.value == nil else { return }
        state = .loaded(detail)
    }

    private func drawMap(of location: EventLocation, key: MapKey) async {
        guard key.size.width > 0, key.size.height > 0, key != mapKey else { return }
        do {
            mapImage = try await snapshotter.snapshot(
                of: location,
                size: key.size,
                scale: key.scale,
                isDark: key.isDark
            )
            mapKey = key
        } catch {
            // A map that cannot be drawn leaves the placeholder; the link still opens Maps.
            if !Task.isCancelled, !Self.isCancellation(error) {
                mapImage = nil
            }
        }
    }

    private func report(_ error: any Error) {
        if let error = error as? NetworkError, case .decoding = error {
            reporter.record(error, context: "Loading an event")
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .cancelled
    }
}
