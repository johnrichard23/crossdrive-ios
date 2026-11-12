/// Where non-fatal errors and the signed-in user's id go. The default drops
/// them; a project adds its vendor behind this protocol.
///
/// `context` says where it happened, in words that carry no personal data.
protocol CrashReporter: Sendable {
    func record(_ error: any Error, context: String)
    /// The signed-in user's id (never an email or a name), or `nil` on sign-out.
    func setUserID(_ id: String?)
}

struct NoCrashReporter: CrashReporter {
    func record(_: any Error, context _: String) {}
    func setUserID(_: String?) {}
}
