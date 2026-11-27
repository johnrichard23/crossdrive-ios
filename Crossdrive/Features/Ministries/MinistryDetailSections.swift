import DesignSystem
import SwiftUI

/// A section title on the ministry screen.
struct MinistrySectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .textRole(.title3, emphasized: true)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The ministry's photos in a row that runs past the screen margins.
struct MinistryPhotosSection: View {
    let photos: [MinistryPhoto]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MinistrySectionHeader(title: "Photos")
            // The first photo lines up with the margins; the rest run on past them.
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(photos) { photo in
                        DSRemoteImage(url: photo.url) { DSImagePlaceholder() }
                            .frame(width: 208, height: 148)
                            .clipShape(DesignSystem.Radius.shape(16))
                            .accessibilityElement()
                            .accessibilityLabel(Text(photo.caption))
                            .accessibilityAddTraits(.isImage)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            Text("Shared with the families' consent.")
                .textRole(.footnote)
                .foregroundStyle(theme.labelSecondary)
        }
        .padding(.top, 10)
    }
}

/// The latest updates from the team, one row each.
struct MinistryUpdatesSection: View {
    let updates: [MinistryUpdate]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MinistrySectionHeader(title: "Latest updates")
            ForEach(updates) { update in
                row(update)
            }
        }
        .padding(.top, 10)
    }

    /// Plain for now: a full update opens once Stories exist.
    private func row(_ update: MinistryUpdate) -> some View {
        HStack(spacing: 12) {
            if update.imageURL != nil {
                DSRemoteImage(url: update.imageURL) { DSImagePlaceholder() }
                    .frame(width: 56, height: 56)
                    .clipShape(DesignSystem.Radius.shape(10))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                if let date = update.dateLabel {
                    Text(date)
                        .textRole(.footnote)
                        .foregroundStyle(theme.labelSecondary)
                }
                Text(update.text)
                    .textRole(.subheadline)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: DesignSystem.Radius.shape(16))
        .overlay(DesignSystem.Radius.shape(16).stroke(theme.separator, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
