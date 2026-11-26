import DataLayer
import DesignSystem
import Foundation
import Observation

/// The trips the person joined, for Events › My events and Profile.
/// Shaped like `EventsViewModel`; reads through the saved copy, so the list
/// opens offline once it has loaded.
@Observable @MainActor
final class MyTripsViewModel {
    private(set) var state: LoadState<[MyTrip]> = .loading
    var toast: DSToast?

    private let repository: Repository<MyTrip>
    private let isSignedIn: @MainActor () -> Bool
    private let now: () -> Date
    private var loadToken = 0

    init(
        repository: Repository<MyTrip>,
        isSignedIn: @escaping @MainActor () -> Bool,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.isSignedIn = isSignedIn
        self.now = now
    }

    /// A guest has no trips, so nothing is asked of the server.
    var isGuest: Bool {
        !isSignedIn()
    }

    func load(forceReload: Bool = false) async {
        if case .loaded = state, !forceReload {
            return
        }
        loadToken += 1
        let token = loadToken
        guard isSignedIn() else {
            state = .loaded([])
            return
        }
        let hadContent = state.value != nil
        if !hadContent {
            state = .loading
        }

        do {
            let trips = try await repository.all()
            guard token == loadToken else { return }
            let current = now()
            state = .loaded(
                trips.filter { !$0.hasEnded(now: current) }
                    .sorted { $0.event.startsAt < $1.event.startsAt }
            )
        } catch {
            guard token == loadToken, !Self.isCancellation(error) else { return }
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

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .cancelled
    }
}
