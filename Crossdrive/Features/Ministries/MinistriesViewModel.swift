import DataLayer
import DesignSystem
import Observation

/// The Ministries list's view model, shaped like `SampleListViewModel`.
@Observable @MainActor
final class MinistriesViewModel {
    private(set) var state: LoadState<[Ministry]> = .loading
    var toast: DSToast?

    private let api: MinistriesAPI
    private let reporter: any CrashReporter
    private var loadToken = 0

    init(api: MinistriesAPI, reporter: any CrashReporter = NoCrashReporter()) {
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
            let ministries = try await api.ministries()
            guard token == loadToken else { return }
            state = .loaded(ministries)
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
            reporter.record(error, context: "Loading ministries")
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .cancelled
    }
}
