import UserNotifications

/// Passes the `link` in a tapped notification's payload to the app, and shows
/// notifications that arrive while the app is open.
///
/// Payload: `{"link": "<scheme>://items/<id>"}` next to `aps`. The system keeps
/// only a weak reference to its delegate, so whoever creates this holds it.
final class NotificationTapHandler: NSObject, UNUserNotificationCenterDelegate {
    private let onTap: @MainActor @Sendable (String) -> Void

    init(onTap: @escaping @MainActor @Sendable (String) -> Void) {
        self.onTap = onTap
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let link = response.notification.request.content.userInfo["link"] as? String else {
            return
        }
        await onTap(link)
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// The only stored property is an immutable closure.
extension NotificationTapHandler: @unchecked Sendable {}
