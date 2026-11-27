import DesignSystem
import SwiftUI

/// One section of the Ministries list: its heading, then its ministries as a
/// row that scrolls sideways (communities, skills) or as cards (the school fund).
struct MinistrySectionView: View {
    let section: MinistrySection

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .textRole(.title2, emphasized: true)
                    .foregroundStyle(theme.labelPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .textRole(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
            .screenMargins()
            content
        }
        .padding(.top, 12)
    }

    @ViewBuilder private var content: some View {
        switch section.kind {
        case .school:
            VStack(spacing: 12) {
                ForEach(section.ministries) { MinistryFundCard(ministry: $0) }
            }
            .screenMargins()
        case .skill:
            row(share: dynamicTypeSize.isAccessibilitySize ? 0.7 : 0.43) {
                MinistrySkillCard(ministry: $0)
            }
        case .bibleStudy, .other:
            row(share: dynamicTypeSize.isAccessibilitySize ? 0.86 : 0.78) {
                MinistryCommunityCard(ministry: $0)
            }
        }
    }

    /// Cards that scroll sideways, each `share` of the screen wide, snapping to
    /// the leading margin.
    private func row(
        share: CGFloat,
        @ViewBuilder card: @escaping (Ministry) -> some View
    ) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(section.ministries) { ministry in
                    card(ministry)
                        .containerRelativeFrame(.horizontal) { width, _ in width * share }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(
            .horizontal,
            theme.spacing.screenMargin(for: sizeClass),
            for: .scrollContent
        )
    }
}
