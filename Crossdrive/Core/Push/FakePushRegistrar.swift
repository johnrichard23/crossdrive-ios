/// A notification centre whose answers are decided by the caller, for
/// previews and tests.
actor FakePushRegistrar: PushRegistrar {
    private var current: PushAuthorization
    private let answerToPrompt: PushAuthorization
    private(set) var promptCount = 0
    private(set) var unregisterCount = 0

    /// `answerToPrompt` is what the user "taps" when the system prompt appears.
    init(
        current: PushAuthorization = .notDetermined,
        answerToPrompt: PushAuthorization = .authorized
    ) {
        self.current = current
        self.answerToPrompt = answerToPrompt
    }

    func authorization() -> PushAuthorization {
        current
    }

    func requestAuthorization() -> PushAuthorization {
        promptCount += 1
        if current == .notDetermined {
            current = answerToPrompt
        }
        return current
    }

    func unregister() {
        unregisterCount += 1
    }
}
