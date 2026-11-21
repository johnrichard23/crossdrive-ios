import AuthenticationServices
import Foundation
import SwiftUI

/// Sign in with Apple. The sheet's own logo button starts it; this runs Apple's
/// request and turns the answer into what the app uses.
enum AppleSignIn {
    /// Asks for the person's name and email and sets a fresh one-time value, which
    /// goes to the server with the token (better-auth compares it with the token's
    /// own copy, as ClubServe's backend does). Returns that value.
    static func prepare(_ request: ASAuthorizationAppleIDRequest) -> String {
        let nonce = UUID().uuidString
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce
        return nonce
    }

    /// Opens Apple's sheet and returns what it gave. Closing the sheet is
    /// `cancelled`, not a failure.
    @MainActor
    static func signIn(
        using controller: AuthorizationController
    ) async -> Result<SocialCredential, any Error> {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        let nonce = prepare(request)
        do {
            let result = try await controller.performRequest(request)
            guard case let .appleID(credential) = result else {
                return .failure(SocialSignInError.missingToken)
            }
            return self.credential(from: credential, nonce: nonce)
        } catch {
            return .failure(mapped(error))
        }
    }

    static func credential(
        from apple: ASAuthorizationAppleIDCredential,
        nonce: String
    ) -> Result<SocialCredential, any Error> {
        guard let data = apple.identityToken,
              let token = String(data: data, encoding: .utf8), !token.isEmpty
        else { return .failure(SocialSignInError.missingToken) }
        return .success(SocialCredential(
            provider: .apple,
            token: token,
            nonce: nonce,
            accessToken: nil
        ))
    }

    /// Apple's "the person closed the sheet" as the app's own `cancelled`.
    static func mapped(_ error: any Error) -> any Error {
        if let error = error as? ASAuthorizationError, error.code == .canceled {
            return SocialSignInError.cancelled
        }
        return error
    }
}
