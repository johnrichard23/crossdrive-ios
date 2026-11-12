import SwiftUI

extension EnvironmentValues {
    /// Whether the device has a connection. Lets a screen retry on its own
    /// when the connection comes back.
    @Entry var isOnline = true

    /// The app's feature flags, for screens that show or hide something.
    @Entry var featureFlags: any FeatureFlags = LocalFeatureFlags(defaults: nil)
}
