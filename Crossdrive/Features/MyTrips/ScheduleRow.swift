import DesignSystem
import SwiftUI

/// One activity on the schedule: its time beside a card with the title, the
/// place and the team. Past ones are greyed; the one on now has an accent
/// border; the next one has a stamp; a moved one says from when.
struct ScheduleRow: View {
    let item: MyTrip.ScheduleItem
    let phase: ScheduleTimeline.Phase
    let tag: ScheduleViewModel.TeamTag

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = 58

    var body: some View {
        // At the largest sizes the card needs the whole width; the time goes above it.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            time
            card
        }
        .accessibilityElement(children: .combine)
    }

    private var time: some View {
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize
        let layout = isAccessibilitySize
            ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 4))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
        return layout {
            Text(MyTrip.clock.format(item.startsAt))
                .textRole(.body, emphasized: true)
                .monospacedDigit()
            Text(MyTrip.dayPeriod(item.startsAt))
                .textRole(.caption1)
                .foregroundStyle(theme.labelSecondary)
        }
        .foregroundStyle(phase == .past ? theme.labelSecondary : theme.labelPrimary)
        .padding(.top, isAccessibilitySize ? 0 : 12)
        .frame(width: isAccessibilitySize ? nil : timeWidth, alignment: .leading)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.title)
                    .textRole(.body, emphasized: phase != .past)
                    .foregroundStyle(phase == .past ? theme.labelSecondary : theme.labelPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                badge
            }
            if let place = item.place {
                Label {
                    Text(place)
                } icon: {
                    DSIcon(.mapPin, role: .subheadline)
                }
                .labelStyle(TightLabelStyle())
                .textRole(.subheadline)
                .foregroundStyle(theme.labelSecondary)
            }
            ScheduleTeamTag(tag: tag)
        }
        .padding(.horizontal, phase == .now ? 13 : 14)
        .padding(.vertical, phase == .now ? 11 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(phase == .past ? theme.background : theme.surface, in: shape)
        .overlay(shape.strokeBorder(border, lineWidth: phase == .now ? 2 : 1))
        .contentShape(shape)
    }

    @ViewBuilder private var badge: some View {
        if phase == .now {
            Text("Now")
                .textRole(.caption1, emphasized: true)
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(theme.accent, in: Capsule())
        } else if let movedFrom = item.movedFrom, phase != .past {
            Text("Moved from \(MyTrip.clock.format(movedFrom))")
                .textRole(.caption1, emphasized: true)
                .foregroundStyle(CDColor.onHarvestSoft)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(CDColor.harvestSoft, in: Capsule())
        } else if phase == .next {
            CDDateStamp(text: String(localized: "Next"))
        }
    }

    private var border: Color {
        switch phase {
        case .now: theme.accent
        case .past: CDColor.meterTrack
        case .next, .later: theme.separator
        }
    }

    private var shape: some InsettableShape {
        DesignSystem.Radius.shape(16)
    }
}

/// The small pill naming an activity's team; the person's own team in purple.
struct ScheduleTeamTag: View {
    let tag: ScheduleViewModel.TeamTag

    @Environment(\.theme) private var theme

    var body: some View {
        Text(tag.label)
            .textRole(.caption1, emphasized: true)
            .foregroundStyle(tag.isMine ? CDColor.onBrandSoft : theme.labelSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(tag.isMine ? CDColor.brandSoft : theme.surfacePressed, in: Capsule())
    }
}

/// An icon and its text 5 points apart, centred on each other.
private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.accessibilityHidden(true)
            configuration.title
        }
    }
}
