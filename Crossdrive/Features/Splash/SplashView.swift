import DesignSystem
import SwiftUI

/// Shown while the app works out where to go. It ends when that work ends,
/// not after a fixed time.
struct SplashView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
            .accessibilityLabel(Text("Loading"))
    }
}

#Preview {
    SplashView()
        .theme(.system)
}
