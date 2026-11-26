import DesignSystem
import SwiftUI

/// One joined trip in Events › My events: photo, kind, where you stand, dates,
/// name, where and when to meet, the fee.
struct MyTripCard: View {
    let trip: MyTrip

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DSRemoteImage(url: trip.event.heroImageURL) { DSImagePlaceholder() }
                .frame(height: 110)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                CDFlowLayout(spacing: 8) {
                    EventKindTag(kind: trip.event.kind)
                    MyTripStatusTag(status: trip.status)
                    CDDateStamp(text: trip.dateRangeLabel)
                }
                Text(trip.event.name)
                    .textRole(.title2, emphasized: true)
                if let meetLine = trip.meetLine {
                    CDMetaRow(icon: .mapPin, text: meetLine)
                } else if let place = trip.event.place {
                    CDMetaRow(icon: .mapPin, text: place)
                }
                if let feeLine = trip.feeLine {
                    CDMetaRow(icon: .peso, text: feeLine)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(DesignSystem.Radius.shape(theme.radius.card))
        .overlay(
            DesignSystem.Radius.shape(theme.radius.card).stroke(theme.separator, lineWidth: 1)
        )
        .contentShape(DesignSystem.Radius.shape(theme.radius.card))
        .accessibilityElement(children: .combine)
    }
}

/// Where the person stands: "You're going" in green, or the quieter waiting
/// pills. `compact` is the short form for a list row.
struct MyTripStatusTag: View {
    let status: MyTrip.Status
    var compact = false

    @Environment(\.theme) private var theme

    var body: some View {
        switch (status, compact) {
        case (.going, _):
            Label {
                Text(compact ? String(localized: "Going") : String(localized: "You're going"))
            } icon: {
                DSIcon(.check, role: .footnote)
            }
            .labelStyle(.titleAndIcon)
            .textRole(.footnote, emphasized: true)
            .foregroundStyle(theme.success)
            .padding(.leading, 7)
            .padding(.trailing, 9)
            .padding(.vertical, 3)
            .background(CDColor.successSoft, in: Capsule())
        case (.pending, _):
            pill(
                compact ? String(localized: "Pending") :
                    String(localized: "Waiting for a coordinator"),
                CDColor.onHarvestSoft,
                CDColor.harvestSoft
            )
        case (.waitlisted, _):
            pill(
                compact ? String(localized: "Waitlisted") :
                    String(localized: "On the waiting list"),
                theme.labelPrimary,
                CDColor.chipFill
            )
        }
    }

    private func pill(_ text: String, _ foreground: Color, _ fill: Color) -> some View {
        Text(text)
            .textRole(.footnote, emphasized: true)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(fill, in: Capsule())
    }
}
