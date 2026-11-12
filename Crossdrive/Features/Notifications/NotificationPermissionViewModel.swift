import Observation

/// Whether notifications are allowed, and asking for it. The system prompt
/// appears only once, so it is only ever triggered from `request()`, after
/// the app's own explanation.
@Observable @MainActor
final class NotificationPermissionViewModel {
    private(set) var authorization: PushAuthorization = .notDetermined
    private(set) var isRequesting = false

    private let push: any PushRegistrar

    init(push: any PushRegistrar) {
        self.push = push
    }

    /// Reads the current answer. Also call it when the app returns from Settings.
    func refresh() async {
        authorization = await push.authorization()
    }

    /// Shows the system prompt. A second tap while it is open does nothing.
    func request() async {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }
        authorization = await push.requestAuthorization()
    }
}
