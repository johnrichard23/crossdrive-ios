import DesignSystem
import SwiftUI
import UIKit

/// My trip › Packing: "What to bring" with a box per item and how many are
/// packed, then the night-before reminder. Both need a connection to change.
struct MyTripPackingTab: View {
    let trip: MyTrip
    let isOnline: Bool
    let reminderNeedsSettings: Bool
    let onToggle: (MyTrip.BringItem.ID) -> Void
    let onReminder: (Bool) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var boxSize: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !trip.bring.isEmpty {
                bringCard
            }
            reminderCard
        }
    }

    // MARK: - What to bring

    private var bringCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ProgressView(value: Double(trip.packedCount), total: Double(trip.bring.count))
                .tint(theme.accent)
                .accessibilityHidden(true)
                .padding(.top, 10)
                .padding(.bottom, isOnline ? 8 : 6)
            if !isOnline {
                Text("Connect to tick items.")
                    .textRole(.footnote)
                    .foregroundStyle(theme.labelSecondary)
                    .padding(.bottom, 8)
            }
            ForEach(trip.bring) { item in
                row(item)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .background(theme.surface, in: DesignSystem.Radius.shape(20))
        .overlay(DesignSystem.Radius.shape(20).stroke(theme.separator, lineWidth: 1))
        .sensoryFeedback(.selection, trigger: trip.packed)
    }

    /// Side by side, or stacked at the largest sizes where the two don't fit.
    private var header: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        return layout {
            Text("What to bring")
                .textRole(.title3, emphasized: true)
                .accessibilityAddTraits(.isHeader)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }
            Text("\(trip.packedCount) of \(trip.bring.count) packed")
                .textRole(.subheadline)
                .foregroundStyle(theme.labelSecondary)
        }
    }

    private func row(_ item: MyTrip.BringItem) -> some View {
        let isPacked = trip.packed.contains(item.id)
        return Button { onToggle(item.id) } label: {
            HStack(spacing: 12) {
                box(isPacked)
                Text(item.title)
                    .textRole(.body)
                    .foregroundStyle(theme.labelPrimary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isOnline)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.surfacePressed).frame(height: 1)
        }
        .accessibilityLabel(Text(item.title))
        .accessibilityValue(Text(isPacked ? "Packed" : "Not packed"))
        .accessibilityAddTraits(.isToggle)
    }

    private func box(_ isPacked: Bool) -> some View {
        DesignSystem.Radius.shape(7)
            .strokeBorder(isPacked ? theme.accent : theme.labelTertiary, lineWidth: 2)
            .background(
                isPacked ? theme.accent : .clear,
                in: DesignSystem.Radius.shape(7)
            )
            .overlay {
                if isPacked {
                    DSIcon(.check, role: .footnote)
                        .foregroundStyle(theme.onAccent)
                }
            }
            .frame(width: boxSize, height: boxSize)
            .opacity(isOnline ? 1 : 0.5)
            .accessibilityHidden(true)
    }

    // MARK: - Reminder

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(get: { trip.remindNightBefore }, set: onReminder)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me the night before")
                        .textRole(.body, emphasized: true)
                    Text("A note the evening before, with where and when to meet.")
                        .textRole(.footnote)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
            .tint(theme.accent)
            .disabled(!isOnline)
            if reminderNeedsSettings {
                Button("Turn on notifications for CrossDrive in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .textRole(.footnote, emphasized: true)
                .foregroundStyle(theme.accent)
                .frame(minHeight: DesignSystem.minTapTarget)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .background(theme.surface, in: DesignSystem.Radius.shape(16))
        .overlay(DesignSystem.Radius.shape(16).stroke(theme.separator, lineWidth: 1))
    }
}
