import Foundation

/// A company the person can sign in with instead of an email and password.
enum SocialProvider: String, Sendable, Equatable {
    case apple
    case facebook
}

/// What a provider hands back after the person agreed on its own screen. The
/// server checks it with the provider; the app never keeps it.
struct SocialCredential: Sendable, Equatable {
    let provider: SocialProvider
    /// The provider's signed identity token (or its access token, when that is all it gave).
    let token: String
    let nonce: String?
    /// Set only when `token` is not an identity token, so the server can ask the provider.
    let accessToken: String?
}

enum SocialSignInError: LocalizedError, Equatable {
    /// The provider's app id is not set for this build.
    case notConfigured
    /// The person closed the provider's screen.
    case cancelled
    /// The provider said yes but gave nothing to send.
    case missingToken

    var errorDescription: String? {
        switch self {
        case .notConfigured, .missingToken:
            String(localized: "That sign-in isn't working right now. Try again, or use your email.")
        case .cancelled:
            nil
        }
    }
}

/// One provider's sign-in, behind a protocol the app owns, so the vendor SDK
/// is imported in one file only and tests never open a provider screen.
protocol SocialSignInProviding: Sendable {
    /// False until the provider is set up for this build; its button stays hidden.
    var isAvailable: Bool { get }

    /// Opens the provider's own screen and returns what it gave.
    func signIn() async throws -> SocialCredential
}

/// The default: the provider is not set up.
struct UnavailableSocialSignIn: SocialSignInProviding {
    var isAvailable: Bool {
        false
    }

    func signIn() async throws -> SocialCredential {
        throw SocialSignInError.notConfigured
    }
}

/// For previews and tests: answers as the caller decides.
struct FakeSocialSignIn: SocialSignInProviding {
    var isAvailable = true
    var result: Result<SocialCredential, any Error> = .success(
        SocialCredential(provider: .facebook, token: "fake-token", nonce: nil, accessToken: nil)
    )

    func signIn() async throws -> SocialCredential {
        try result.get()
    }
}
