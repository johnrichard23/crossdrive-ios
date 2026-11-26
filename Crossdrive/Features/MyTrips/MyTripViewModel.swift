import DataLayer
import DesignSystem
import Foundation
import Observation

/// One joined trip: where and when to meet, what is left to do, what is next,
/// and the packing list. Reads through the saved copy, so it opens at the pier
/// with no signal. Ticks and the reminder are server writes, so they need one.
@Observable @MainActor
final class MyTripViewModel {
    enum Tab: Hashable, CaseIterable {
        case trip
        case packing

        var title: String {
            switch self {
            case .trip: String(localized: "Trip")
            case .packing: String(localized: "Packing")
            }
        }
    }

    private(set) var state: LoadState<MyTrip> = .loading
    var tab: Tab = .trip
    var isShowingToDos = false
    var toast: DSToast?
    /// Set by the screen from the connection; ticks and the reminder wait for it.
    var isOnline = true
    /// Notifications are off in Settings, so the reminder can't be turned on here.
    private(set) var reminderNeedsSettings = false

    let tripID: Event.ID
    private let repository: Repository<MyTrip>
    private let store: any Store<MyTrip>
    private let api: MyTripsAPI
    private let push: any PushRegistrar
    private let now: () -> Date
    private var loadToken = 0
    private var packingInFlight: Set<MyTrip.BringItem.ID> = []
    private var isSavingReminder = false

    init(
        tripID: Event.ID,
        container: DependencyContainer,
        now: @escaping () -> Date = Date.init
    ) {
        self.tripID = tripID
        repository = container.myTrips
        store = container.myTripsStore
        api = container.myTripsAPI
        push = container.services.push
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
            await reloadSavedCopy()
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
            state = .loaded(keepingSavesInFlight(trip))
        } catch {
            guard token == loadToken, !Self.isCancellation(error) else { return }
            if hadContent {
                toast = .error(error.userMessage)
            } else {
                state = error.isOffline ? .offline : .failed(error.userMessage)
            }
        }
    }

    // MARK: - Packing

    /// Ticks or clears one item: the box flips at once, and flips back with a
    /// toast if the server says no. A tap while that item is saving is ignored.
    func toggle(_ item: MyTrip.BringItem.ID) async {
        guard isOnline, !packingInFlight.contains(item), let trip = state.value else { return }
        packingInFlight.insert(item)
        defer { packingInFlight.remove(item) }
        let packed = !trip.packed.contains(item)
        change { $0.setPacked(packed, item) }
        do {
            try await api.setPacked(packed, item: item, registration: trip.registrationID)
        } catch {
            change { $0.setPacked(!packed, item) }
            toast = .error(String(localized: "Couldn't save. Try again."))
        }
        await saveCopy()
    }

    // MARK: - Reminder

    /// Turning it on asks for notification permission first; if that is off,
    /// the switch stays off and the screen points to Settings.
    func setReminder(_ isOn: Bool) async {
        guard isOnline, !isSavingReminder, let trip = state.value,
              trip.remindNightBefore != isOn
        else { return }
        isSavingReminder = true
        defer { isSavingReminder = false }
        if isOn {
            var permission = await push.authorization()
            if permission == .notDetermined {
                permission = await push.requestAuthorization()
            }
            guard permission == .authorized else {
                reminderNeedsSettings = true
                return
            }
        }
        reminderNeedsSettings = false
        change { $0.remindNightBefore = isOn }
        do {
            try await api.setReminder(isOn, registration: trip.registrationID)
        } catch {
            change { $0.remindNightBefore = !isOn }
            toast = .error(String(localized: "Couldn't save. Try again."))
        }
        await saveCopy()
    }

    private func change(_ edit: (inout MyTrip) -> Void) {
        guard var trip = state.value else { return }
        edit(&trip)
        state = .loaded(trip)
    }

    /// Another screen (the reminder sheet) may have ticked items since this one
    /// loaded, so a screen that comes back shows what the phone has saved.
    private func reloadSavedCopy() async {
        guard let saved = try? await store.item(id: tripID)?.item else { return }
        state = .loaded(keepingSavesInFlight(saved))
    }

    /// A fresh copy must not undo a tick or reminder change that is still saving.
    private func keepingSavesInFlight(_ fresh: MyTrip) -> MyTrip {
        guard let shown = state.value else { return fresh }
        var trip = fresh
        for item in packingInFlight {
            trip.setPacked(shown.packed.contains(item), item)
        }
        if isSavingReminder {
            trip.remindNightBefore = shown.remindNightBefore
        }
        return trip
    }

    /// Keeps the phone's copy in step, so the list opens ticked with no signal.
    private func saveCopy() async {
        guard let trip = state.value else { return }
        // The screen already shows the change; the next load saves it again.
        try? await store.save([Stored(id: trip.id, item: trip, fetchedAt: now())])
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

private extension MyTrip {
    mutating func setPacked(_ isPacked: Bool, _ item: BringItem.ID) {
        if isPacked {
            packed.insert(item)
        } else {
            packed.remove(item)
        }
    }
}
