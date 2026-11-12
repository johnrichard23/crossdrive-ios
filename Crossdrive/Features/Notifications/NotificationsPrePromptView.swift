import DesignSystem
import SwiftUI

/// The app's own explanation, shown before the system prompt. Only Continue
/// leads to the system prompt, so a "Not now" doesn't spend the one chance
/// the system gives to ask.
struct NotificationsPrePromptView: View {
    let onContinue: @MainActor () -> Void
    let onNotNow: @MainActor () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        DSStateView(
            "Stay in the loop",
            message: "We'll only send what you ask for, like an update on an item you follow.",
            systemImage: "bell.badge",
            actionTitle: "Continue",
            action: onContinue,
            secondaryActionTitle: "Not now",
            secondaryAction: onNotNow
        )
        .background(theme.background)
    }
}

#Preview {
    NotificationsPrePromptView(onContinue: {}, onNotNow: {})
        .theme(.system)
}
