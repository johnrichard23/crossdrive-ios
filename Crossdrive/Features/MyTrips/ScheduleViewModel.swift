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
    var selectedDay: ScheduleTimeline.Day.ID?
    /// A fetch is out, for the retry buttons.
    private(set) var isLoading = false
    var toast: DSToast?

    let tripID: Event.ID
    private let repository: Repository<MyTrip>
    private let now: () -> Date
    private var myTeam: MyTrip.Team?
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

    /// A fresh open starts on today during the trip, else day 1, whatever
    /// day was picked the last time.
    func startOnToday() {
        selectedDay = timeline?.dayToOpen(now: now())
    }

    var selectedItems: [MyTrip.ScheduleItem] {
        timeline?.days.first { $0.id == selectedDay }?.items ?? []
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
        let timeline = ScheduleTimeline(schedule: schedule)
        // A refresh keeps the day the person picked, if it is still there.
        if !timeline.days.contains(where: { $0.id == selectedDay }) {
            selectedDay = timeline.dayToOpen(now: now())
        }
        self.timeline = timeline
        updatedAt = schedule.updatedAt
        content = .ready
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? NetworkError) == .cancelled
    }
}
