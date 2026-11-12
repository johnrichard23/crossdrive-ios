import DesignSystem
import SwiftUI

/// Shown instead of the app when the build configuration can't be read.
/// A developer sees this, never a user: it means an `.xcconfig` is wrong.
struct ConfigurationErrorView: View {
    let error: AppEnvironment.ConfigurationError

    @Environment(\.theme) private var theme

    var body: some View {
        DSStateView(
            String(localized: "The app isn't configured"),
            message: message,
            systemImage: "wrench.and.screwdriver"
        )
        .background(theme.background)
    }

    private var message: String {
        switch error {
        case let .missing(key):
            String(localized: "\(key) is missing. Set it in the Config folder.")
        case let .invalid(key, value):
            String(localized: "\(key) has a value that can't be used: \(value)")
        }
    }
}

#Preview {
    ConfigurationErrorView(error: .missing(key: "API_BASE_URL"))
        .theme(.system)
}
