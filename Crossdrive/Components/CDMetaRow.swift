import DesignSystem
import SwiftUI

/// One line of detail with an icon in front: a place, a cost. The icon sits in
/// a column of the same width on every row, centred on the first line of text,
/// so icons and texts line up from one row to the next, and a long text that
/// wraps keeps its icon beside the first line.
struct CDMetaRow: View {
    let icon: DSIcon.Source
    let text: String
    var role: DesignSystem.TextRole = .subheadline

    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var iconColumn: CGFloat = 20

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // The hidden text gives the column one line of height; the icon is centred in it.
            Text("M")
                .hidden()
                .frame(width: iconColumn)
                .overlay { DSIcon(icon, role: role).foregroundStyle(theme.labelSecondary) }
                .accessibilityHidden(true)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .textRole(role)
        .foregroundStyle(theme.labelSecondary)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        CDMetaRow(icon: .mapPin, text: "Behia, Bagatao Island")
        CDMetaRow(icon: .peso, text: "₱1,500 covers boat and meals")
        CDMetaRow(
            icon: .mapPin,
            text: "A very long place name that wraps onto a second line to check the icon"
        )
    }
    .padding()
    .theme(.crossdrive)
}
