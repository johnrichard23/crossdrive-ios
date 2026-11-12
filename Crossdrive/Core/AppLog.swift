import DataLayer
import OSLog

/// The app's only logging entry point. `print` is banned by lint.
///
/// Use the logger for the area you are in, and mark anything that could
/// identify a person as private so it is redacted outside a debugger:
///
///     AppLog.session.info("Signed in as \(email, privacy: .private)")
///     AppLog.network.error("Load failed: \(AppLog.summary(error), privacy: .public)")
///
/// Never log tokens, passwords, request headers or request bodies. An error's
/// own text can carry the server's words (an echoed email, say), so log it
/// with `summary(_:)` in public and the full text, if at all, as private.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app"

    /// Launch, configuration and anything without a better home.
    static let app = Logger(subsystem: subsystem, category: "app")
    /// Requests and responses, without headers or bodies.
    static let network = Logger(subsystem: subsystem, category: "network")
    /// Sign-in, sign-out, token refresh.
    static let session = Logger(subsystem: subsystem, category: "session")
    /// Flow changes, deep links, push-notification taps.
    static let navigation = Logger(subsystem: subsystem, category: "navigation")

    /// An error's type and, for a network error, its status code. Nothing the
    /// user typed or the server wrote, so it is safe to log as public.
    static func summary(_ error: any Error) -> String {
        if let error = error as? NetworkError {
            return error.statusCode.map { "NetworkError \($0)" } ?? "NetworkError"
        }
        return String(describing: type(of: error))
    }
}
