import DesignSystem
import SwiftUI

extension Ministry {
    /// Made-up ministries of every kind with every part present, so the
    /// placeholder sections have the same shape as real ones. Their words are
    /// never read: they are redacted.
    static let placeholders: [Ministry] = {
        let community = (1 ... 2).map { number in
            Ministry(
                id: "placeholder-community-\(number)",
                name: "Community",
                schedule: "Every week",
                place: "Placeholder town, province",
                summary: "",
                kind: .bibleStudy
            )
        }
        let fund = Ministry(
            id: "placeholder-fund",
            name: "Placeholder fund",
            schedule: "Every month",
            summary: "A line or two about what a gift pays for and who it helps.",
            kind: .school,
            fund: Ministry.Fund(kidsPaid: 1, kidsGoal: 2)
        )
        return community + [fund]
    }()
}

/// The sections the Ministries list shows while it loads: the real sections
/// with made-up words, redacted and shimmering, so nothing moves when they arrive.
struct MinistriesSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(MinistrySection.sections(from: Ministry.placeholders, showing: nil)) {
                MinistrySectionView(section: $0)
            }
        }
        // Grey and faint: card colours would read as real content.
        .saturation(0)
        .opacity(0.5)
        .dsLoading(true)
        .allowsHitTesting(false)
        .accessibilityLabel("Loading ministries")
    }
}

#Preview("Loading") {
    ScrollView {
        MinistriesSkeleton()
    }
    .theme(.crossdrive)
}
