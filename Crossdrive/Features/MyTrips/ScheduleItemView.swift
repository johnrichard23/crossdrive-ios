import DesignSystem
import SwiftUI

/// One activity: when, what and which team, then where it is, what to bring,
/// who to ask, and what comes after it.
struct ScheduleItemView: View {
    let viewModel: ScheduleViewModel
    let itemID: MyTrip.ScheduleItem.ID

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if let item = viewModel.item(itemID) {
                details(item)
            } else {
                DSStateView(
                    "This activity is no longer on the schedule",
                    message: "The coordinators may have moved or removed it.",
                    systemImage: "calendar"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func details(_ item: MyTrip.ScheduleItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    CDDateStamp(text: timeRange(item))
                    Text(item.title)
                        .textRole(.title1, emphasized: true)
                        .foregroundStyle(theme.labelPrimary)
                        .accessibilityAddTraits(.isHeader)
                    ScheduleTeamTag(tag: viewModel.teamTag(for: item))
                }
                .accessibilityElement(children: .combine)
                if let summary = item.summary {
                    Text(summary)
                        .textRole(.body)
                        .foregroundStyle(theme.labelSecondary)
                        .padding(.top, 2)
                }
                VStack(spacing: 0) {
                    if let place = item.place {
                        section("Where", icon: .mapPin, value: place) {
                            if let url = TripLinks.maps(
                                latitude: item.latitude,
                                longitude: item.longitude,
                                name: place
                            ) {
                                Button("Directions") { openURL(url) }
                                    .buttonStyle(.ds(.outline, size: .regular))
                            }
                        }
                    }
                    if let bring = item.bring {
                        section("Bring", icon: .system("bag"), value: bring) { EmptyView() }
                    }
                    if let lead = item.ask {
                        section("Ask", icon: .user, value: askLine(lead, team: item.team)) {
                            if let url = TripLinks.call(lead.phone) {
                                Button("Call \(lead.name)") { openURL(url) }
                                    .buttonStyle(.ds(.outline, size: .regular))
                            }
                        }
                    }
                }
                if let next = viewModel.item(after: item.id) {
                    afterThis(next)
                }
            }
            .screenMargins()
            .padding(.top, 8)
            .padding(.bottom, theme.spacing.groupGap)
        }
    }

    private func section(
        _ title: LocalizedStringKey,
        icon: DSIcon.Source,
        value: String,
        @ViewBuilder action: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(title)
                } icon: {
                    DSIcon(icon, role: .footnote).accessibilityHidden(true)
                }
                .textRole(.footnote, emphasized: true)
                .foregroundStyle(theme.labelSecondary)
                Text(value)
                    .textRole(.body)
                    .foregroundStyle(theme.labelPrimary)
            }
            .accessibilityElement(children: .combine)
            action().padding(.top, 4)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CDColor.meterTrack).frame(height: 1)
        }
    }

    private func afterThis(_ next: MyTrip.ScheduleItem) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        return layout {
            Text("After this")
                .foregroundStyle(theme.labelSecondary)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }
            Text("\(MyTrip.time.format(next.startsAt)) · \(next.title)")
                .fontWeight(.semibold)
                .foregroundStyle(theme.labelPrimary)
        }
        .textRole(.subheadline)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    /// "10:30 AM to 12:00 PM", or the start alone when there is no end.
    private func timeRange(_ item: MyTrip.ScheduleItem) -> String {
        let start = MyTrip.time.format(item.startsAt)
        guard let endsAt = item.endsAt else { return start }
        return String(localized: "\(start) to \(MyTrip.time.format(endsAt))")
    }

    /// "Mark, the film crew lead", or the name alone for an all-team activity.
    private func askLine(_ lead: MyTrip.Lead, team: MyTrip.Team?) -> String {
        guard let team else { return lead.name }
        return String(localized: "\(lead.name), the \(team.name.lowercased()) lead")
    }
}

#Preview {
    let container = DependencyContainer.preview()
    let model = ScheduleViewModel(tripID: "behia-going", repository: container.myTrips)
    return NavigationStack {
        ScheduleItemView(viewModel: model, itemID: "film")
            .task { await model.load() }
    }
    .theme(.crossdrive)
}
