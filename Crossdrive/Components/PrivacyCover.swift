import DesignSystem
import SwiftUI

extension View {
    /// Covers the screen whenever the app isn't in front, so the app-switcher
    /// snapshot (and anyone glancing during the switch) doesn't show it. Put it
    /// on screens with personal, payment or account details.
    ///
    /// It covers on `.inactive` too, not just `.background`, because the
    /// switcher shows the live screen while the app is merely inactive.
    func privacyCover() -> some View {
        modifier(PrivacyCover())
    }
}

private struct PrivacyCover: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content.overlay {
            if scenePhase != .active {
                theme.background
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
    }
}
