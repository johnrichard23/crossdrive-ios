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
    var hasAgreed = true

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
    /// The pictures on the email step; empty until they load, or if they can't.
    private(set) var photos: [UIImage] = []
    /// True until the pictures are in or have failed, so the page keeps their place.
    private(set) var isLoadingMedia = true
    /// The small picture in the trip reminder.
    private(set) var tripImage: UIImage?

    let trip: GateTrip?

    private let accountAPI: AccountAPI
    private let imageLoader: any ImageLoading
    private let signIn: (Credentials) async throws -> Void
    private let minimumPasswordLength = 8

    init(
        trip: GateTrip?,
        accountAPI: AccountAPI,
        imageLoader: any ImageLoading,
        signIn: @escaping (Credentials) async throws -> Void
    ) {
        self.trip = trip
        self.accountAPI = accountAPI
        self.imageLoader = imageLoader
        self.signIn = signIn
    }

    /// The email without the spaces around it.
    var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Makes the four pictures and the trip's small picture. Anything that
    /// can't be had is left out; the sheet works without pictures.
    func loadMedia(scale: CGFloat) async {
        defer { isLoadingMedia = false }
        let urls = await (try? accountAPI.welcomePhotos()) ?? []
        let loader = imageLoader
        let cell = ImageDownsampler.maxPixels(for: CGSize(width: 200, height: 112), scale: scale)
        let thumb = ImageDownsampler.maxPixels(for: CGSize(width: 40, height: 40), scale: scale)
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, url) in urls.prefix(4).enumerated() {
                group.addTask { await (index, loader.image(for: url, maxPixels: cell)) }
            }
            if let url = trip?.imageURL {
                group.addTask { await (-1, loader.image(for: url, maxPixels: thumb)) }
            }
            var loaded: [Int: UIImage] = [:]
            for await (index, image) in group {
                if let image {
                    loaded[index] = image
                }
            }
            tripImage = loaded[-1]
            let ordered = (0 ..< 4).compactMap { loaded[$0] }
            // A mosaic needs all four; with fewer the sheet shows none.
            photos = ordered.count == 4 ? ordered : []
        }
    }

    func emailDidEndEditing() {
        emailError = Self.emailProblem(in: email)
    }

    // MARK: - Email step

    /// Asks the server if the email has an account, then moves on.
    @discardableResult
    func continueWithEmail() async -> Field? {
        guard !isSubmitting else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }

        emailError = Self.emailProblem(in: email)
        if emailError != nil {
            formError = nil
            return fail(.email)
        }
        formError = nil
        do {
            switch try await accountAPI.status(ofEmail: trimmedEmail) {
            case .hasAccount: show(.password)
            case .newEmail: show(.create)
            }
            return nil
        } catch is CancellationError {
            return nil
        } catch NetworkError.noConnection {
            formError = String(localized: "You're offline. Connect to the internet to sign in.")
            return fail(nil)
        } catch {
            // When the answer can't be had, ask for the password: never push a
            // person with an account into making a second one.
            show(.password)
            return nil
        }
    }

    // MARK: - Password step

    @discardableResult
    func signInTapped() async -> Field? {
        guard !isSubmitting else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }

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
            passwordError =
                String(localized: "That password doesn't match. Try again, or reset it.")
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

        do {
            switch try await accountAPI.signUp(
                name: trimmedName,
                email: trimmedEmail,
                password: password
            ) {
            case .created:
                try await signIn(Credentials(email: trimmedEmail, password: password))
            case .needsEmailVerification:
                show(.checkEmail)
            }
            formError = nil
            return nil
        } catch is CancellationError {
            return nil
        } catch AuthError.emailAlreadyExists {
            password = ""
            passwordError = nil
            formError = String(localized: "This email already has an account. Sign in instead.")
            path = [.password]
            return fail(nil)
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
