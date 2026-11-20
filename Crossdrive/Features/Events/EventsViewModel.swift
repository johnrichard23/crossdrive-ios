import DataLayer
import DesignSystem
import Observation

/// The Events list's view model, shaped like `SampleListViewModel`.
@Observable @MainActor
final class EventsViewModel {
    /// Which list is showing.
    enum Scope: Hashable, CaseIterable {
        case upcoming
        case mine

        var title: String {
            switch self {
            case .upcoming: "Upcoming"
            case .mine: "My events"
            }
        }
    }

    private(set) var state: LoadState<[Event]> = .loading
    var scope: Scope = .upcoming
    /// The kind chip that is on. `nil` means All.
    var kind: EventKind?
    var toast: DSToast?

    private let api: EventsAPI
    private let imageLoader: any ImageLoading
    private let snapshotter: any MapSnapshotting
    private let reporter: any CrashReporter
    private var loadToken = 0
    /// The detail view models for the trips that are open in the stack, so a
    /// re-render of the list does not build a new one each time.
    @ObservationIgnored private var detailModels: [Event.ID: EventDetailViewModel] = [:]

    init(
        api: EventsAPI,
        imageLoader: any ImageLoading,
        snapshotter: any MapSnapshotting,
        reporter: any CrashReporter = NoCrashReporter()
    ) {
        self.api = api
        self.imageLoader = imageLoader
        self.snapshotter = snapshotter
        self.reporter = reporter
    }

    /// The one view model for the trip `id`, made the first time it is asked for.
    func detailViewModel(for id: Event.ID) -> EventDetailViewModel {
        if let cached = detailModels[id] {
            return cached
        }
        let model = EventDetailViewModel(
            api: api,
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

    /// The loaded events that pass the kind chip.
    var visibleEvents: [Event] {
        let events = state.value ?? []
        guard let kind else { return events }
        return events.filter { $0.kind == kind }
    }

    func load(forceReload: Bool = false) async {
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
            let events = try await api.events()
            guard token == loadToken else { return }
            state = .loaded(events)
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

    /// The device is back online: retry what failed because it wasn't.
    func connectionRestored() async {
        switch state {
        case .offline, .failed: await load()
        case .loading, .loaded: break
        }
    }

    private func report(_ error: any Error) {
        if let error = error as? NetworkError, case .decoding = error {
            reporter.record(error, context: "Loading events")
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .cancelled
    }
}
