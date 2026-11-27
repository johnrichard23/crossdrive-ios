import DataLayer
import DesignSystem
import Foundation
import Observation

/// One joined trip: where and when to meet, what is left to do, what is next.
/// Reads through the saved copy, so it opens at the pier with no signal.
@Observable @MainActor
final class MyTripViewModel {
    private(set) var state: LoadState<MyTrip> = .loading
    var isShowingToDos = false
    var toast: DSToast?

    let tripID: Event.ID
    private let repository: Repository<MyTrip>
    private let now: () -> Date
    private var loadToken = 0

    init(
        tripID: Event.ID,
        repository: Repository<MyTrip>,
        now: @escaping () -> Date = Date.init
    ) {
        self.tripID = tripID
        self.repository = repository
        self.now = now
    }

    var countdown: String? {
        state.value?.countdown(now: now())
    }

    /// The next activity, for confirmed volunteers only.
    var upNext: MyTrip.ScheduleItem? {
        guard let trip = state.value, trip.status == .going,
              let schedule = trip.schedule, schedule.published
        else { return nil }
        return ScheduleTimeline(schedule: schedule).upNext(now: now())
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
            let trip = try await repository.item(id: tripID)
            guard token == loadToken else { return }
            state = .loaded(trip)
        } catch {
            guard token == loadToken, !Self.isCancellation(error) else { return }
            if hadContent {
                toast = .error(error.userMessage)
            } else {
                state = error.isOffline ? .offline : .failed(error.userMessage)
            }
        }
    }

    /// The device is back online: refresh, so a saved copy is replaced.
    func connectionRestored() async {
        switch state {
        case .offline, .failed: await load()
        case .loaded: await load(forceReload: true)
        case .loading: break
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .cancelled
    }
}
