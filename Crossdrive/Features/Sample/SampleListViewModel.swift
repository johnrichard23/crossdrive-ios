import DataLayer
import DesignSystem
import Observation

/// The reference view model: copy its shape for any screen that loads data.
///
/// - Stale-response guard: a reply from an older load is ignored.
/// - Load-once guard: `load()` does nothing once loaded, unless forced.
/// - In-flight guard: a write blocks a second write for the same item, set
///   before the first `await`.
/// - Refresh keeps the current content on screen; a failed refresh shows a toast.
@Observable @MainActor
final class SampleListViewModel {
    private(set) var state: LoadState<[Item]> = .loading
    private(set) var favoritesInFlight: Set<Item.ID> = []
    var toast: DSToast?

    private let api: SampleAPI
    private let reporter: any CrashReporter
    private var loadToken = 0

    init(api: SampleAPI, reporter: any CrashReporter = NoCrashReporter()) {
        self.api = api
        self.reporter = reporter
    }

    func item(withID id: Item.ID) -> Item? {
        state.value?.first { $0.id == id }
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
            let items = try await api.items()
            guard token == loadToken else { return }
            state = .loaded(items)
        } catch {
            // A cancelled load (the view went away) leaves things as they were.
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

    func toggleFavorite(_ id: Item.ID) async {
        guard let item = item(withID: id), !favoritesInFlight.contains(id) else { return }
        favoritesInFlight.insert(id)
        defer { favoritesInFlight.remove(id) }

        let newValue = !item.isFavorite
        setFavorite(newValue, for: id)
        do {
            try await api.setFavorite(newValue, forItem: id)
        } catch {
            setFavorite(!newValue, for: id)
            if !Self.isCancellation(error) {
                toast = .error(error.userMessage)
            }
        }
    }

    private func setFavorite(_ value: Bool, for id: Item.ID) {
        guard case var .loaded(items) = state,
              let index = items.firstIndex(where: { $0.id == id })
        else { return }
        items[index].isFavorite = value
        state = .loaded(items)
    }

    /// A reply the app can't read is a bug, not the user's problem: report it.
    private func report(_ error: any Error) {
        if let error = error as? NetworkError, case .decoding = error {
            reporter.record(error, context: "Loading items")
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .cancelled
    }
}
