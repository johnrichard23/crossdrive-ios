import DesignSystem
import SwiftUI

/// A small pill with one fact, on a light lavender-gray fill: "3 days, 2 nights",
/// "₱1,500". No outline; the fill alone sets it apart from the card or page.
struct CDChip: View {
    enum Tone {
        /// A plain fact.
        case plain
        /// Where the person stands with the trip ("You're going"): the soft purple.
        case status
        /// Something to do ("Waiver not signed yet").
        case warning
    }

    let text: String
    var tone: Tone = .plain
    var role: DesignSystem.TextRole = .footnote

    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .textRole(role, emphasized: tone != .plain)
            .foregroundStyle(foreground)
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .frame(minHeight: 30)
            .background(fill, in: Capsule())
    }

    private var fill: Color {
        tone == .status ? CDColor.brandSoft : CDColor.chipFill
    }

    private var foreground: Color {
        switch tone {
        case .plain: theme.labelPrimary
        case .status: CDColor.onBrandSoft
        case .warning: theme.warning
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        CDChip(text: "3 days, 2 nights")
        CDChip(text: "You're going", tone: .status)
        CDChip(text: "Waiver not signed yet", tone: .warning)
    }
    .padding()
}
