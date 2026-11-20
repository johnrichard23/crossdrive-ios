import DesignSystem
import SwiftUI

/// The full-width pill action on a ticket: 52 pt tall, fully rounded, accent fill.
struct CDPillButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textRole(.headline, emphasized: true)
            .foregroundStyle(theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                configuration.isPressed ? theme.accentPressed : theme.accent,
                in: Capsule()
            )
    }
}
