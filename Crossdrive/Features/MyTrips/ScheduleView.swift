import DataLayer
import DesignSystem
import SwiftUI

/// A trip's schedule: a tab per day, then that day's activities with what is
/// on now and what is next. Opens on today during the trip, else day 1.
struct ScheduleView: View {
    @State private var viewModel: ScheduleViewModel

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline
    @Environment(\.dismiss) private var dismiss
    /// The day picked on this screen. Each push starts on today; coming back
    /// from an activity keeps it, and another tab's schedule has its own.
    @State private var pickedDay: ScheduleTimeline.Day.ID?

    init(viewModel: ScheduleViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .dsToast($viewModel.toast)
            .task { await viewModel.load() }
            .onChange(of: isOnline) { _, isOnline in
                if isOnline {
                    Task { await viewModel.load() }
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.content {
        case .loading:
            ScheduleSkeleton()
        case .ready:
            if let timeline = viewModel.timeline {
                ready(timeline)
            }
        case .notConfirmed where viewModel.isWaitlisted:
            ScheduleNotice(
                icon: .system("lock"),
                title: "Your schedule opens when you're confirmed",
                message: "You're on the waiting list. We'll message you if a place opens up."
            ) { dismiss() }
        case .notConfirmed:
            ScheduleNotice(
                icon: .system("lock"),
                title: "Your schedule opens when you're confirmed",
                message: "A coordinator is checking your registration. We'll message you as soon as you're in."
            ) { dismiss() }
        case .notPublished:
            ScheduleNotice(
                icon: .calendar,
                title: "The schedule isn't ready yet",
                message: "The coordinators will publish it before the trip. We'll tell you when it's up."
            ) { dismiss() }
        case let .failed(message):
            DSStateView.error(
                message: message,
                isRetrying: viewModel.isLoading,
                title: "Couldn't load the schedule"
            ) {
                Task { await viewModel.load() }
            }
        case .offline:
            DSStateView.offline(isRetrying: viewModel.isLoading) { Task { await viewModel.load() } }
        }
    }

    private func ready(_ timeline: ScheduleTimeline) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScheduleDayTabs(days: timeline.days, selection: dayBinding)
                if isOnline {
                    savedLine
                } else {
                    offlineBanner
                }
                let items = viewModel.items(on: viewModel.dayToShow(keeping: pickedDay))
                // The minute ticks over so Now and Next move on by themselves.
                TimelineView(.everyMinute) { context in
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            NavigationLink(value: EventsRoute.activity(
                                viewModel.tripID,
                                item.id
                            )) {
                                ScheduleRow(
                                    item: item,
                                    phase: timeline.phase(of: item, now: context.date),
                                    tag: viewModel.teamTag(for: item)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .screenMargins()
            .padding(.top, 8)
            .padding(.bottom, theme.spacing.groupGap)
        }
        .refreshable { await viewModel.load() }
    }

    private var dayBinding: Binding<ScheduleTimeline.Day.ID?> {
        Binding(
            get: { viewModel.dayToShow(keeping: pickedDay) },
            set: { pickedDay = $0 }
        )
    }

    private var savedLine: some View {
        Label {
            if let updatedAt = viewModel.updatedAt {
                Text("Saved on this phone · Updated \(MyTrip.time.format(updatedAt))")
            } else {
                Text("Saved on this phone")
            }
        } icon: {
            DSIcon(.system("checkmark.icloud"), role: .footnote)
        }
        .textRole(.footnote)
        .foregroundStyle(theme.labelSecondary)
    }

    private var offlineBanner: some View {
        Label {
            if let savedAt = viewModel.savedAt {
                let time = MyTrip.time.format(savedAt)
                Text(
                    "You're offline. This is the schedule saved at \(time). Times may have changed."
                )
            } else {
                Text("You're offline. Times may have changed.")
            }
        } icon: {
            DSIcon(.system("wifi.slash"), role: .subheadline)
        }
        .textRole(.subheadline)
        .foregroundStyle(theme.labelSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfacePressed, in: DesignSystem.Radius.shape(12))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// The day tabs: weekday, date and day number. Equal widths when they fit,
/// else a row that scrolls.
struct ScheduleDayTabs: View {
    let days: [ScheduleTimeline.Day]
    @Binding var selection: ScheduleTimeline.Day.ID?

    @Environment(\.theme) private var theme
    /// Counts taps, so the haptic answers a tap and not a day picked for the person.
    @State private var taps = 0

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { tabs }
            ScrollView(.horizontal) {
                HStack(spacing: 8) { tabs }
            }
            .scrollIndicators(.hidden)
        }
        .sensoryFeedback(.selection, trigger: taps)
    }

    private var tabs: some View {
        ForEach(days) { day in
            let isOn = day.id == selection
            Button {
                selection = day.id
                taps += 1
            } label: {
                VStack(spacing: 1) {
                    Text(MyTrip.weekday.format(day.id))
                        .textRole(.footnote)
                        .foregroundStyle(isOn ? theme.background.opacity(0.8) : theme
                            .labelSecondary)
                    Text(MyTrip.dayOfMonth.format(day.id))
                        .textRole(.title2, emphasized: true)
                        .foregroundStyle(isOn ? theme.background : theme.labelPrimary)
                        .monospacedDigit()
                    Text("Day \(day.number)")
                        .textRole(.caption1)
                        .foregroundStyle(isOn ? theme.background.opacity(0.8) : theme
                            .labelSecondary)
                }
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(
                    isOn ? theme.labelPrimary : theme.surface,
                    in: DesignSystem.Radius.shape(16)
                )
                .overlay(
                    DesignSystem.Radius.shape(16)
                        .strokeBorder(isOn ? theme.labelPrimary : theme.separator, lineWidth: 1)
                )
                .contentShape(DesignSystem.Radius.shape(16))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(MyTrip.longDay.format(day.id)), day \(day.number)"))
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        }
    }
}

/// Why the schedule can't show yet, with a way back to My trip.
private struct ScheduleNotice: View {
    let icon: DSIcon.Source
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let onBack: () -> Void

    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .title2) private var circle: CGFloat = 64

    var body: some View {
        // Centred when it fits, else it scrolls at the largest text sizes.
        ViewThatFits(in: .vertical) {
            notice.frame(maxHeight: .infinity)
            ScrollView { notice.padding(.vertical, 24) }
        }
    }

    private var notice: some View {
        VStack(spacing: 10) {
            DSIcon(icon, role: .title2)
                .foregroundStyle(CDColor.onBrandSoft)
                .frame(width: circle, height: circle)
                .background(CDColor.brandSoft, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .textRole(.title2, emphasized: true)
                .foregroundStyle(theme.labelPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .textRole(.body)
                .foregroundStyle(theme.labelSecondary)
            Button("Back to My trip", action: onBack)
                .buttonStyle(.ds(.outline, size: .regular))
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }
}

// MARK: - Previews

@MainActor
private func schedulePreview(
    _ id: Event.ID,
    now: Date = Date(timeIntervalSince1970: 1_796_000_000),
    _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse = SampleStub.handle
) -> some View {
    let container = DependencyContainer.preview(client: StubHTTPClient(handler))
    return NavigationStack {
        ScheduleView(
            viewModel: ScheduleViewModel(
                tripID: id,
                repository: container.myTrips,
                store: container.myTripsStore,
                now: { now }
            )
        )
    }
    .theme(.crossdrive)
}

#Preview("Day 1") { schedulePreview("behia-going") }
#Preview("Not confirmed") { schedulePreview("camp-feb") }
#Preview("Offline, nothing saved") {
    schedulePreview("behia-going") { _ in throw NetworkError.noConnection }
}
