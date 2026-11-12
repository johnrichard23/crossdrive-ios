import Observation

/// The sign-in form. Validates a field when the user leaves it and every
/// field on submit; a wrong password is a form-level message, never a hint
/// about which of the two was wrong.
@Observable @MainActor
final class SignInViewModel {
    enum Field {
        case email
        case password
    }

    var email = ""
    var password = ""
    private(set) var emailError: String?
    private(set) var passwordError: String?
    private(set) var formError: String?
    private(set) var isSubmitting = false
    /// Goes up on every failed attempt; the view plays the error haptic on change.
    private(set) var failureCount = 0

    private let signIn: (Credentials) async throws -> Void

    init(signIn: @escaping (Credentials) async throws -> Void) {
        self.signIn = signIn
    }

    func emailDidEndEditing() {
        emailError = Self.emailProblem(in: email)
    }

    func passwordDidEndEditing() {
        passwordError = Self.passwordProblem(in: password)
    }

    /// Validates, then signs in. Returns the field that needs attention, so
    /// the view can move focus there; `nil` when it succeeded or the problem
    /// isn't about a field.
    @discardableResult
    func submit() async -> Field? {
        guard !isSubmitting else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }

        formError = nil
        emailError = Self.emailProblem(in: email)
        passwordError = Self.passwordProblem(in: password)
        if emailError != nil {
            return fail(.email)
        }
        if passwordError != nil {
            return fail(.password)
        }

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await signIn(Credentials(email: trimmed, password: password))
            return nil
        } catch is CancellationError {
            return nil
        } catch AuthError.invalidCredentials {
            formError = AuthError.invalidCredentials.userMessage
            return fail(.password)
        } catch {
            formError = error.userMessage
            return fail(nil)
        }
    }

    private func fail(_ field: Field?) -> Field? {
        failureCount += 1
        return field
    }

    private static func emailProblem(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return String(localized: "Enter your email address.")
        }
        if trimmed.wholeMatch(of: /[^@\s]+@[^@\s]+\.[^@\s]+/) == nil {
            return String(localized: "Enter an email like name@example.com.")
        }
        return nil
    }

    private static func passwordProblem(in text: String) -> String? {
        text.isEmpty ? String(localized: "Enter your password.") : nil
    }
}
