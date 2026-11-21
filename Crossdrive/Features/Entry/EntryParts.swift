import DesignSystem
import SwiftUI

/// "Behia Mission Trip, Dec 12 to 14 · Behia, Bagatao Island" with a small picture.
struct EntryTripChip: View {
    let trip: GateTrip
    let image: UIImage?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            CDColor.pineGround
                .overlay {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(trip.title).textRole(.subheadline, emphasized: true)
                if !trip.detail.isEmpty {
                    Text(trip.detail)
                        .textRole(.footnote)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.separator, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// A step's title and the line under it.
struct EntryHeading: View {
    let title: LocalizedStringKey
    let message: Text

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .csDisplay(size: 26, lineHeight: 31, tracking: -0.26)
                .accessibilityAddTraits(.isHeader)
            message
                .textRole(.subheadline)
                .foregroundStyle(theme.labelSecondary)
        }
    }
}

/// A line of small text with an icon: the offline note and form-level problems.
struct EntryStatusLine: View {
    let systemImage: String
    let text: String
    var isError = false

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(text)
        }
        .textRole(.subheadline)
        .foregroundStyle(isError ? theme.destructive : theme.labelSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
