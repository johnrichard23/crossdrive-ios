import DesignSystem
import SwiftUI

/// One ministry in the Ministries list: photo, schedule stamp, name, place,
/// what it is, and the Pray and Give buttons. The photo and words open it.
struct MinistryCard: View {
    let ministry: Ministry

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Only the top opens the ministry; Pray and Give stay their own buttons.
            NavigationLink(value: MinistriesRoute.detail(ministry.id)) {
                VStack(alignment: .leading, spacing: 0) {
                    DSRemoteImage(url: ministry.imageURL) { DSImagePlaceholder() }
                        .frame(height: 104)
                        .accessibilityHidden(true)
                    details
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            actions
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(DesignSystem.Radius.shape(theme.radius.card))
        .overlay(
            DesignSystem.Radius.shape(theme.radius.card).stroke(theme.separator, lineWidth: 1)
        )
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let schedule = ministry.schedule {
                CDDateStamp(text: schedule)
            }
            Text(ministry.name)
                .textRole(.title3, emphasized: true)
                .accessibilityAddTraits(.isHeader)
            if let place = ministry.place {
                CDMetaRow(icon: .mapPin, text: place)
            }
            if !ministry.summary.isEmpty {
                Text(ministry.summary)
                    .textRole(.callout)
                    .foregroundStyle(theme.labelSecondary)
            }
        }
    }

    /// Pray and Give side by side, stacked at accessibility sizes.
    private var actions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            Button("Pray") {}
                .buttonStyle(.ds(.secondary))
            Button("Give") {}
                .buttonStyle(.ds(.primary))
        }
    }
}
