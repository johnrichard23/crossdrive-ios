import DataLayer
import DesignSystem
import Observation

/// The Ministries list: every ministry, grouped by kind, with a chip per kind.
@Observable @MainActor
final class MinistriesViewModel {
    private(set) var state: LoadState<[Ministry]> = .loading
    var toast: DSToast?
    /// The filter chip that is on; `nil` is All.
    var kind: Ministry.Kind?

    /// The list's sections under the current chip. A chip whose kind is gone
    /// after a refresh shows everything again.
    var sections: [MinistrySection] {
        let ministries = state.value ?? []
        let shown = kind.flatMap { MinistrySection.kinds(in: ministries).contains($0) ? $0 : nil }
        return MinistrySection.sections(from: ministries, showing: shown)
    }

    /// The chips after All: one per kind on the list.
    var kinds: [Ministry.Kind] {
        MinistrySection.kinds(in: state.value ?? [])
    }

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
