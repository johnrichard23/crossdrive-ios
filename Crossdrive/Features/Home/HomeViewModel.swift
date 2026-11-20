import DataLayer
import DesignSystem
import Observation

/// Home's view model, shaped like `SampleListViewModel`: stale-response guard,
/// load-once guard, and a refresh that keeps the content on screen.
@Observable @MainActor
final class HomeViewModel {
    private(set) var state: LoadState<HomeSummary> = .loading
    var toast: DSToast?

    private let api: HomeAPI
    private let reporter: any CrashReporter
    private var loadToken = 0

    init(api: HomeAPI, reporter: any CrashReporter = NoCrashReporter()) {
        self.api = api
        self.reporter = reporter
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
            let summary = try await api.home()
            guard token == loadToken else { return }
            state = .loaded(summary)
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
