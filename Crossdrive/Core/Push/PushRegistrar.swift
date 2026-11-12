/// Whether the user has allowed notifications.
enum PushAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
}

/// Everything the app needs from the notification system, behind one seam.
///
/// The base does the permission part. Sending a remote push also needs the
/// `aps-environment` entitlement, a call to `registerForRemoteNotifications()`
/// and a way to give the device token to the server; each is the project's.
/// `unregister()` is where the server is told to stop sending to this device.
protocol PushRegistrar: Sendable {
    func authorization() async -> PushAuthorization
    /// Shows the system prompt (once; later calls just report the answer).
    func requestAuthorization() async -> PushAuthorization
    /// Called first on sign-out, while the session still works.
    func unregister() async
}
