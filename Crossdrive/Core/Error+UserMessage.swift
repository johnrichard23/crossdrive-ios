import DataLayer

extension Error {
    /// Plain-language text for the user: what happened and what to do, with
    /// no status codes. Add a case here when a screen needs different words.
    var userMessage: String {
        if let authError = self as? AuthError, authError == .invalidCredentials {
            return String(localized: "Incorrect email or password.")
        }
        guard let error = self as? NetworkError else {
            return String(localized: "Something went wrong. Try again.")
        }
        switch error {
        case .noConnection:
            return String(localized: "You're offline. Check your connection and try again.")
        case .timeout:
            return String(localized: "That took too long. Try again.")
        case .unauthorized:
            return String(localized: "Your session ended. Sign in again.")
        case .forbidden:
            return String(localized: "You don't have access to this.")
        case .notFound:
            return String(localized: "We couldn't find that. It may have been removed.")
        case .server:
            return String(localized: "Something went wrong on our side. Try again in a moment.")
        case .client:
            // The server's own words suit a rejected request (for example, a validation message).
            return error.serverMessage.flatMap { $0.isEmpty ? nil : $0 }
                ?? String(localized: "We couldn't complete that. Check your details and try again.")
        case .insecureConnection, .invalidURL, .invalidResponse, .decoding, .cancelled, .unknown:
            return String(localized: "Something went wrong. Try again.")
        }
    }
}
