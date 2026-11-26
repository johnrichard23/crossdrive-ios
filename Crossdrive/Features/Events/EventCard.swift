import DesignSystem
import SwiftUI

/// One event in the Events list: photo, tags (with where the person stands,
/// once they joined), title, where, cost, slots.
struct EventCard: View {
    let event: Event
    var status: MyTrip.Status?

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DSRemoteImage(url: event.heroImageURL) { DSImagePlaceholder() }
                .frame(height: 110)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                tags
                Text(event.title)
                    .textRole(.title2, emphasized: true)
                if let placeLine = event.placeLine {
                    CDMetaRow(icon: .mapPin, text: placeLine)
                }
                if let fee = event.feeLabel {
                    CDMetaRow(icon: .peso, text: fee)
                }
                if event.slotsTakenLabel != nil {
                    slots
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

    private var tags: some View {
        row(spacing: 8) {
            kindTag
            if let status {
                MyTripStatusTag(status: status, compact: true)
            }
            CDDateStamp(text: event.dateRangeLabel)
        }
    }

    private var kindTag: some View {
        EventKindTag(kind: event.kind)
    }

    private var slots: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(spacing: 8) {
                if let taken = event.slotsTakenLabel {
                    Text(taken)
                        .foregroundStyle(theme.labelSecondary)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                }
                if let left = event.slotsLabel {
                    Text(left)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.accent)
                }
            }
            .textRole(.footnote)
            ProgressView(value: event.takenFraction)
                .progressViewStyle(SlotsBarStyle())
        }
    }

    /// Side by side normally, stacked at accessibility sizes.
    private func row(spacing: CGFloat, @ViewBuilder _ content: () -> some View) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        return layout { content() }
    }
}

/// The thin bar that shows how full an event is.
private struct SlotsBarStyle: ProgressViewStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.surfacePressed)
                Capsule()
                    .fill(theme.accent)
                    .frame(width: proxy.size.width * (configuration.fractionCompleted ?? 0))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// "Mission trip" on a soft purple, or "Camp" outlined: the kind tag on a card.
struct EventKindTag: View {
    let kind: EventKind

    @Environment(\.theme) private var theme

    var body: some View {
        switch kind {
        case .trip:
            Text(kind.tagLabel)
                .textRole(.footnote, emphasized: true)
                .foregroundStyle(CDColor.onBrandSoft)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(CDColor.brandSoft, in: Capsule())
        case .camp:
            Text(kind.tagLabel)
                .textRole(.footnote, emphasized: true)
                .foregroundStyle(theme.labelPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .overlay(Capsule().stroke(theme.labelPrimary, lineWidth: 1.5))
        }
    }
}
