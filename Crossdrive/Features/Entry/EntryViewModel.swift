import DataLayer
import Foundation
import Observation
import UIKit

/// The sign-in sheet: email first, then the password or the new-account step.
/// One view model for the whole sheet; it is freed when the sheet closes.
@Observable @MainActor
final class EntryViewModel {
    /// The steps pushed over the email step.
    enum Step: Hashable {
        case password
        case create
        case checkEmail
        case reset
    }

    /// Which field a failed submit wants attention on.
    enum Field {
        case email
        case name
        case password
    }

    var path: [Step] = []
    var email = ""
    var name = ""
    var password = ""
    /// Starts unticked: agreeing is the person's own choice.
    var hasAgreed = false

    private(set) var emailError: String?
    private(set) var nameError: String?
    private(set) var passwordError: String?
    private(set) var agreementError: String?
    private(set) var formError: String?
    private(set) var isSubmitting = false
    /// Sign-in is paused after too many wrong tries.
    private(set) var isLocked = false
    /// Shown on the reset step once the link has been asked for.
    private(set) var resetNotice: String?
    /// Goes up on every failed attempt; the view plays the error haptic on change.
    private(set) var failureCount = 0
    /// The small picture in the trip reminder.
    private(set) var tripImage: UIImage?

    let trip: GateTrip?

    private let accountAPI: AccountAPI
    private let imageLoader: any ImageLoading
    private let facebook: any SocialSignInProviding
    private let signIn: (Credentials) async throws -> Void
    private let signInWithSocial: (SocialCredential) async throws -> Void
    private let minimumPasswordLength = 8
    /// The details just signed up, kept in memory only while "Check your email"
    /// waits, so signing in can resume once the email is confirmed.
    private var unverified: Credentials?

    init(
        trip: GateTrip?,
        accountAPI: AccountAPI,
        imageLoader: any ImageLoading,
        facebook: any SocialSignInProviding = UnavailableSocialSignIn(),
        signIn: @escaping (Credentials) async throws -> Void,
        signInWithSocial: @escaping (SocialCredential) async throws -> Void
    ) {
        self.trip = trip
        self.accountAPI = accountAPI
        self.imageLoader = imageLoader
        self.facebook = facebook
        self.signIn = signIn
        self.signInWithSocial = signInWithSocial
    }

    /// The giving sheet's step row, when this sign-in is a step of giving.
    var givingSteps: [String]? {
        if case let .give(steps) = trip?.purpose {
            return steps
        }
        return nil
    }

    /// The email without the spaces around it.
    var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Loads the trip's small picture for the reminder. Without it the
    /// reminder just has no picture.
    func loadTripImage(scale: CGFloat) async {
        guard let url = trip?.imageURL else { return }
        let thumb = ImageDownsampler.maxPixels(for: CGSize(width: 40, height: 40), scale: scale)
        tripImage = await imageLoader.image(for: url, maxPixels: thumb)
    }

    func emailDidEndEditing() {
        emailError = Self.emailProblem(in: email)
    }

    // MARK: - Email step

    /// "Continue": on to the password. The app never asks the server whether the
    /// email has an account, so nothing here can tell anyone who does.
    @discardableResult
    func continueTapped() -> Field? {
        moveOn(to: .password)
    }

    /// "Create an account": on to the new-account step.
    @discardableResult
    func createTapped() -> Field? {
        moveOn(to: .create)
    }

    private func moveOn(to step: Step) -> Field? {
        formError = nil
        emailError = Self.emailProblem(in: email)
        if emailError != nil {
            return fail(.email)
        }
        show(step)
        return nil
    }

    // MARK: - Apple and Facebook

    /// Whether the Facebook button should show: only once it is set up for this build.
    var canUseFacebook: Bool {
        facebook.isAvailable
    }

    /// "Continue with Facebook": Facebook's own screen, then the server checks
    /// what it gave. Closing that screen is not an error.
    func facebookTapped() async {
        await finishSocial { try await facebook.signIn() }
    }

    /// Apple's own button has answered. `result` comes from `AppleSignIn`.
    func appleFinished(_ result: Result<SocialCredential, any Error>) async {
        await finishSocial { try result.get() }
    }

    private func finishSocial(_ obtain: () async throws -> SocialCredential) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        formError = nil
        do {
            try await signInWithSocial(obtain())
        } catch is CancellationError {
            return
        } catch SocialSignInError.cancelled {
            return
        } catch {
            formError = error.userMessage
            failureCount += 1
        }
    }

    // MARK: - Password step

    @discardableResult
    func signInTapped() async -> Field? {
        guard !isSubmitting else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }

        formError = nil
        if password.isEmpty {
            passwordError = String(localized: "Enter your password.")
            return fail(.password)
        }
        do {
            try await signIn(Credentials(email: trimmedEmail, password: password))
            passwordError = nil
            formError = nil
            return nil
        } catch is CancellationError {
            return nil
        } catch AuthError.invalidCredentials {
            // The same words whether the email has an account or not.
            passwordError =
                String(localized: "That email or password doesn't match. Try again, or reset it.")
            return fail(.password)
        } catch AuthError.accountLocked {
            return lock()
        } catch let error as NetworkError where error.statusCode == 429 || error.statusCode == 423 {
            return lock()
        } catch {
            passwordError = nil
            formError = error.userMessage
            return fail(nil)
        }
    }

    // MARK: - Create step

    @discardableResult
    func createAccountTapped() async -> Field? {
        guard !isSubmitting else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }

        formError = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        nameError = trimmedName.isEmpty ? String(localized: "Enter your name.") : nil
        passwordError = passwordProblemForNewAccount
        agreementError = hasAgreed ? nil : String(localized: "Agree to continue.")
        if nameError != nil {
            return fail(.name)
        }
        if passwordError != nil {
            return fail(.password)
        }
        if agreementError != nil {
            return fail(nil)
        }

        // What was sent is what signs in, even if the fields are edited meanwhile.
        let credentials = Credentials(email: trimmedEmail, password: password)
        do {
            switch try await accountAPI.signUp(
                name: trimmedName,
                email: credentials.email,
                password: credentials.password,
                hasAgreed: hasAgreed
            ) {
            case .created:
                try await signIn(credentials)
            case .needsEmailVerification:
                unverified = credentials
                show(.checkEmail)
            }
            formError = nil
            return nil
        } catch is CancellationError {
            return nil
        } catch {
            formError = error.userMessage
            return fail(nil)
        }
    }

    /// The count in "This one has 5." is of the characters typed so far.
    func passwordDidChange() {
        if passwordError != nil, path.last == .create {
            passwordError = passwordProblemForNewAccount
        }
    }

    // MARK: - Reset and verification

    @discardableResult
    func sendResetLinkTapped() async -> Field? {
        guard !isSubmitting else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }

        emailError = Self.emailProblem(in: email)
        if emailError != nil {
            return fail(.email)
        }
        do {
            try await accountAPI.sendResetLink(toEmail: trimmedEmail)
            resetNotice =
                String(localized: "If \(trimmedEmail) has an account, a link is on its way.")
            formError = nil
            return nil
        } catch is CancellationError {
            return nil
        } catch {
            resetNotice = nil
            formError = error.userMessage
            return fail(nil)
        }
    }

    /// The person is back in the app on "Check your email": if they confirmed it,
    /// signing in now works and the tapped action goes on. Still unconfirmed is
    /// not an error; the step just stays.
    func resumeAfterVerification() async {
        guard path.last == .checkEmail, let credentials = unverified, !isSubmitting else {
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        if await (try? signIn(credentials)) != nil {
            unverified = nil
        }
    }

    func resendVerificationTapped() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await accountAPI.sendVerificationLink(toEmail: trimmedEmail)
            formError = nil
        } catch is CancellationError {
            return
        } catch {
            formError = error.userMessage
            failureCount += 1
        }
    }

    /// "Forgot your password?" and "Reset my password" on the locked screen.
    func showReset() {
        show(.reset)
    }

    // MARK: - Private

    private func show(_ step: Step) {
        password = ""
        passwordError = nil
        nameError = nil
        agreementError = nil
        formError = nil
        isLocked = false
        resetNotice = nil
        path.append(step)
    }

    private func lock() -> Field? {
        isLocked = true
        passwordError = String(
            localized: "Too many tries, so sign-in is paused for 15 minutes. Reset your password to get back in now."
        )
        return fail(.password)
    }

    private func fail(_ field: Field?) -> Field? {
        failureCount += 1
        return field
    }

    private var passwordProblemForNewAccount: String? {
        password.count >= minimumPasswordLength
            ? nil
            : String(localized: "Use at least 8 characters. This one has \(password.count).")
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
}
