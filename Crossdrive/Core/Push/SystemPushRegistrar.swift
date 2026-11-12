import UserNotifications

/// The real notification centre.
struct SystemPushRegistrar: PushRegistrar {
    func authorization() async -> PushAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return switch settings.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .authorized
        @unknown default: .denied
        }
    }

    func requestAuthorization() async -> PushAuthorization {
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            AppLog.app
                .error(
                    """
                    Notification permission failed: \(AppLog.summary(error), privacy: .public) \
                    \(String(describing: error), privacy: .private)
                    """
                )
        }
        return await authorization()
    }

    // shortcut: nothing to undo until a project registers a device token.
    func unregister() async {}
}
