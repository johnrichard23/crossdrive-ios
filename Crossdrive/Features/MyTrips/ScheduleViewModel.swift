import DataLayer
import DesignSystem
import Foundation
import Observation

/// A joined trip's schedule, day by day, for confirmed volunteers. Reads
/// through the saved copy, so it opens offline; times are checked again each
/// time it opens, since coordinators move them.
@Observable @MainActor
final class ScheduleViewModel {
    enum Content: Equatable {
        case loading
        case ready
        /// Still waiting for a coordinator, or on the waiting list.
        case notConfirmed
        case notPublished
        case failed(String)
        case offline
    }

    /// An activity's team: everyone, another team, or the person's own.
    struct TeamTag: Equatable {
        let label: String
        let isMine: Bool
    }

    private(set) var content: Content = .loading
    private(set) var timeline: ScheduleTimeline?
    /// When the coordinators last changed the schedule.
    private(set) var updatedAt: Date?
    /// When this phone last saved the trip, for the offline banner.
    private(set) var savedAt: Date?
    /// Not confirmed because the trip is full, not because it is being checked.
    private(set) var isWaitlisted = false
    /// A fetch is out, for the retry buttons.
    private(set) var isLoading = false
    var toast: DSToast?

    let tripID: Event.ID
    private let repository: Repository<MyTrip>
    private let store: any Store<MyTrip>
    private let now: () -> Date
    private var myTeam: MyTrip.Team?
    private var loadToken = 0

    init(
        tripID: Event.ID,
        repository: Repository<MyTrip>,
        store: any Store<MyTrip>,
        now: @escaping () -> Date = Date.init
    ) {
        self.tripID = tripID
        self.repository = repository
        self.store = store
        self.now = now
    }

    /// Fetches the trip, or keeps what is shown and says why it couldn't.
    func load() async {
        loadToken += 1
        let token = loadToken
        isLoading = true
        defer {
            if token == loadToken {
                isLoading = false
            }
        }
        do {
            let trip = try await repository.item(id: tripID)
            guard token == loadToken else { return }
            let saved = try? await store.item(id: tripID)?.fetchedAt
            guard token == loadToken else { return }
            savedAt = saved
            show(trip)
        } catch {
            guard token == loadToken, !Self.isCancellation(error) else { return }
            if content == .ready {
                toast = .error(error.userMessage)
            } else {
                content = error.isOffline ? .offline : .failed(error.userMessage)
            }
        }
    }

    /// The day to show: the one the screen picked while it is still on the
    /// schedule, else today during the trip, else day 1.
    func dayToShow(keeping picked: ScheduleTimeline.Day.ID?) -> ScheduleTimeline.Day.ID? {
        guard let timeline else { return nil }
        if timeline.days.contains(where: { $0.id == picked }) {
            return picked
        }
        return timeline.dayToOpen(now: now())
    }

    func items(on day: ScheduleTimeline.Day.ID?) -> [MyTrip.ScheduleItem] {
        timeline?.days.first { $0.id == day }?.items ?? []
    }

    func item(_ id: MyTrip.ScheduleItem.ID) -> MyTrip.ScheduleItem? {
        allItems.first { $0.id == id }
    }

    /// The activity that starts after this one, on any day.
    func item(after id: MyTrip.ScheduleItem.ID) -> MyTrip.ScheduleItem? {
        guard let index = allItems.firstIndex(where: { $0.id == id }) else { return nil }
        return allItems.dropFirst(index + 1).first
    }

    func teamTag(for item: MyTrip.ScheduleItem) -> TeamTag {
        guard let team = item.team else {
            return TeamTag(label: String(localized: "Everyone"), isMine: false)
        }
        guard team.id == myTeam?.id else { return TeamTag(label: team.name, isMine: false) }
        return TeamTag(label: String(localized: "\(team.name) · your team"), isMine: true)
    }

    // MARK: - Private

    private var allItems: [MyTrip.ScheduleItem] {
        timeline?.days.flatMap(\.items) ?? []
    }

    private func show(_ trip: MyTrip) {
        myTeam = trip.team
        isWaitlisted = trip.status == .waitlisted
        guard trip.status == .going else {
            timeline = nil
            content = .notConfirmed
            return
        }
        guard let schedule = trip.schedule, schedule.published, !schedule.items.isEmpty else {
            timeline = nil
            content = .notPublished
            return
        }
        timeline = ScheduleTimeline(schedule: schedule)
        updatedAt = schedule.updatedAt
        content = .ready
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .cancelled
    }
}
