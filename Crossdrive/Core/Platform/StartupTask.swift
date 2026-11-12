/// Work to do once the app is up, without holding up the first screen: sync a
/// device token, warm a cache, refresh remote config.
///
/// Tasks run in the background, one after another, so keep each short and
/// make it safe to run twice.
struct StartupTask: Sendable {
    enum Trigger: Sendable {
        /// Once per launch.
        case launch
        /// At launch if a session was restored, and after every sign-in.
        case signedIn
    }

    let name: String
    let trigger: Trigger
    let run: @Sendable () async -> Void
}
