import DataLayer
import Observation

/// The ministry detail screen's view model, shaped like `SampleListViewModel`.
@Observable @MainActor
final class MinistryDetailViewModel {
    private(set) var state: LoadState<MinistryDetail> = .loading
    /// The ministry is gone or was taken down (the server said not found).
    private(set) var isUnavailable = false

    private let api: MinistriesAPI
    private let reporter: any CrashReporter
    private let ministryID: Ministry.ID
    private var loadToken = 0

    init(
        api: MinistriesAPI,
        ministryID: Ministry.ID,
        reporter: any CrashReporter = NoCrashReporter()
    ) {
        self.api = api
        self.ministryID = ministryID
        self.reporter = reporter
    }

    func load(forceReload: Bool = false) async {
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
            let detail = try await api.ministry(id: ministryID)
            guard token == loadToken else { return }
            state = .loaded(detail)
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

    /// The device is back online: retry what failed because it wasn't.
    func connectionRestored() async {
        switch state {
        case .offline, .failed: await load()
        case .loading, .loaded: break
        }
    }

    private func report(_ error: any Error) {
        if let error = error as? NetworkError, case .decoding = error {
            reporter.record(error, context: "Loading a ministry")
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .cancelled
    }
}
