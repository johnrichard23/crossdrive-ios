import DataLayer
import DesignSystem
import Observation
import UIKit

/// Home's view model, shaped like `SampleListViewModel`: stale-response guard,
/// load-once guard, and a refresh that keeps the content on screen.
@Observable @MainActor
final class HomeViewModel {
    private(set) var state: LoadState<HomeSummary> = .loading
    /// The next trip's photo and the film card's photo, decoded at the size shown.
    private(set) var tripImage: UIImage?
    private(set) var storyImage: UIImage?
    /// The big number and its words, worked out once per load and per day change.
    private(set) var countdown: HomeCountdown?
    var toast: DSToast?

    /// Where the two photos are shown, so they are ready before the screen appears.
    struct MediaLayout: Equatable, Sendable {
        var tripSize: CGSize
        var storySize: CGSize
        var scale: CGFloat
    }

    private let api: HomeAPI
    private let eventsAPI: EventsAPI
    private let snapshotter: any MapSnapshotting
    private let reporter: any CrashReporter
    private let imageLoader: any ImageLoading
    private let now: @Sendable () -> Date
    private let mediaDeadline: @Sendable () async -> Void
    private var loadToken = 0
    /// The detail view models for the trips open in Home's stack, so a re-render
    /// does not build a new one each time.
    @ObservationIgnored private var detailModels: [Event.ID: EventDetailViewModel] = [:]

    init(
        api: HomeAPI,
        eventsAPI: EventsAPI,
        imageLoader: any ImageLoading,
        snapshotter: any MapSnapshotting,
        reporter: any CrashReporter = NoCrashReporter(),
        now: @escaping @Sendable () -> Date = { Date() },
        mediaDeadline: @escaping @Sendable () async -> Void = {
            try? await Task.sleep(for: .seconds(3))
        }
    ) {
        self.api = api
        self.eventsAPI = eventsAPI
        self.snapshotter = snapshotter
        self.imageLoader = imageLoader
        self.reporter = reporter
        self.now = now
        self.mediaDeadline = mediaDeadline
    }

    /// Loads Home. With `media`, the loading state stays up until the two photos
    /// are ready too (3 seconds at most), so nothing pops in after the screen shows.
    func load(media: MediaLayout? = nil, forceReload: Bool = false) async {
        if case .loaded = state, !forceReload {
            return
        }

        loadToken += 1
        let token = loadToken
        let hadContent = state.value != nil
        if !hadContent {
            state = .loading
        }

        do {
            let summary = try await api.home()
            guard token == loadToken else { return }
            if let media, !hadContent {
                await revealWhenMediaIsReady(summary, media: media, token: token)
            } else {
                show(summary)
                if let media {
                    await loadImages(of: summary, media: media)
                }
            }
        } catch {
            guard token == loadToken, !Self.isCancellation(error) else { return }
            report(error)
            if hadContent {
                toast = .error(error.userMessage)
            } else {
                state = error.isOffline ? .offline : .failed(error.userMessage)
            }
        }
    }

    /// The one view model for the trip `id`, made the first time it is asked for.
    func detailViewModel(for id: Event.ID) -> EventDetailViewModel {
        if let cached = detailModels[id] {
            return cached
        }
        let model = EventDetailViewModel(
            api: eventsAPI,
            eventID: id,
            imageLoader: imageLoader,
            snapshotter: snapshotter,
            reporter: reporter
        )
        detailModels[id] = model
        return model
    }

    /// Frees the view models of trips that are no longer in the stack.
    func openTripsChanged(to ids: [Event.ID]) {
        detailModels = detailModels.filter { ids.contains($0.key) }
    }

    /// The app is back in front: the number may have changed at midnight.
    func refreshCountdown() {
        countdown = state.value?.trip?.countdown(now: now())
    }

    /// The device is back online: retry what failed because it wasn't.
    func connectionRestored(media: MediaLayout? = nil) async {
        switch state {
        case .offline, .failed: await load(media: media)
        case .loading, .loaded: break
        }
    }

    // MARK: - Media

    private func revealWhenMediaIsReady(
        _ summary: HomeSummary,
        media: MediaLayout,
        token: Int
    ) async {
        await MediaGate.reveal(
            after: imageLoads(of: summary, media: media),
            deadline: mediaDeadline
        ) { [weak self] in
            guard let self, token == loadToken, state.value == nil else { return }
            show(summary)
        }
    }

    /// A refresh keeps the screen up and only swaps the photos when they arrive.
    private func loadImages(of summary: HomeSummary, media: MediaLayout) async {
        await withTaskGroup(of: Void.self) { group in
            for load in imageLoads(of: summary, media: media) {
                group.addTask { await load() }
            }
        }
    }

    private func imageLoads(
        of summary: HomeSummary,
        media: MediaLayout
    ) -> [@Sendable () async -> Void] {
        let loader = imageLoader
        var loads: [@Sendable () async -> Void] = []
        if let url = summary.trip?.event.heroImageURL {
            let pixels = ImageDownsampler.maxPixels(for: media.tripSize, scale: media.scale)
            loads.append { [weak self] in
                let image = await loader.image(for: url, maxPixels: pixels)
                await self?.setTripImage(image)
            }
        }
        if let url = summary.latestStory?.imageURL {
            let pixels = ImageDownsampler.maxPixels(for: media.storySize, scale: media.scale)
            loads.append { [weak self] in
                let image = await loader.image(for: url, maxPixels: pixels)
                await self?.setStoryImage(image)
            }
        }
        return loads
    }

    private func setTripImage(_ image: UIImage?) {
        if let image {
            tripImage = image
        }
    }

    private func setStoryImage(_ image: UIImage?) {
        if let image {
            storyImage = image
        }
    }

    private func show(_ summary: HomeSummary) {
        // A refresh that no longer has a photo must not keep the old one.
        if summary.trip?.event.heroImageURL == nil {
            tripImage = nil
        }
        if summary.latestStory?.imageURL == nil {
            storyImage = nil
        }
        state = .loaded(summary)
        countdown = summary.trip?.countdown(now: now())
    }

    /// A reply the app can't read is a bug, not the user's problem: report it.
    private func report(_ error: any Error) {
        if let error = error as? NetworkError, case .decoding = error {
            reporter.record(error, context: "Loading Home")
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .cancelled
    }
}
