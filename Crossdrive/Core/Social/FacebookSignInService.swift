import FacebookCore
import FacebookLogin
import Foundation
import UIKit

/// Facebook sign-in. The only file that imports the Facebook SDK.
///
/// It uses Limited Login (no tracking, no App Tracking Transparency prompt):
/// Facebook returns an identity token the server can check, or, if it can't,
/// a classic access token.
struct FacebookSignInService: SocialSignInProviding {
    /// Set `FACEBOOK_APP_ID` and `FACEBOOK_CLIENT_TOKEN` in the build settings
    /// (`Config/Shared.xcconfig`, or the environment's file) to switch it on.
    static var isConfigured: Bool {
        let appID = Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String
        return !(appID ?? "").isEmpty
    }

    var isAvailable: Bool {
        Self.isConfigured
    }

    func signIn() async throws -> SocialCredential {
        guard Self.isConfigured else { throw SocialSignInError.notConfigured }
        return try await Self.logIn()
    }

    /// The SDK wants the launch and the links that come back from Facebook.
    @MainActor
    static func applicationDidLaunch() {
        guard isConfigured else { return }
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )
    }

    @MainActor
    static func handle(_ url: URL) {
        guard isConfigured else { return }
        _ = ApplicationDelegate.shared.application(
            UIApplication.shared,
            open: url,
            options: [:]
        )
    }

    @MainActor
    private static func logIn() async throws -> SocialCredential {
        let nonce = UUID().uuidString
        guard let configuration = LoginConfiguration(
            permissions: ["public_profile", "email"],
            tracking: .limited,
            nonce: nonce
        ) else { throw SocialSignInError.notConfigured }

        let manager = LoginManager()
        return try await withCheckedThrowingContinuation { continuation in
            manager.logIn(configuration: configuration) { result in
                switch result {
                case .cancelled:
                    continuation.resume(throwing: SocialSignInError.cancelled)
                case let .failed(error):
                    continuation.resume(throwing: error)
                case let .success(_, _, accessToken):
                    if let identity = AuthenticationToken.current?.tokenString {
                        continuation.resume(returning: SocialCredential(
                            provider: .facebook,
                            token: identity,
                            nonce: nonce,
                            accessToken: nil
                        ))
                    } else if let classic = accessToken ?? AccessToken.current {
                        continuation.resume(returning: SocialCredential(
                            provider: .facebook,
                            token: classic.tokenString,
                            nonce: nil,
                            accessToken: classic.tokenString
                        ))
                    } else {
                        continuation.resume(throwing: SocialSignInError.missingToken)
                    }
                }
            }
        }
    }
}
