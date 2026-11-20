import DesignSystem
import SwiftUI

extension Ministry {
    /// Made-up ministries with every part present, so the placeholder cards have
    /// the same shape as real ones. Their words are never read: they are redacted.
    static let placeholders: [Ministry] = (1 ... 2).map { number in
        Ministry(
            id: "placeholder-\(number)",
            name: "Placeholder ministry",
            schedule: "Every week",
            place: "Placeholder place",
            summary: "A line or two about what this ministry does and who it is for.",
            imageURL: nil
        )
    }
}

/// The cards the Ministries list shows while it loads: the real cards with
/// made-up words, redacted and shimmering, so nothing moves when they arrive.
struct MinistriesSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(Ministry.placeholders) { ministry in
                MinistryCard(ministry: ministry)
            }
        }
        // Grey and faint, like the canvas: card colours would read as real content.
        .saturation(0)
        .opacity(0.5)
        .dsLoading(true)
    }
}

#Preview("Loading") {
    ScrollView {
        MinistriesSkeleton().screenMargins()
    }
    .background(Color(.systemGroupedBackground))
}
