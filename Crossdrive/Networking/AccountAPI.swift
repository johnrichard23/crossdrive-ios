import DataLayer
import Foundation

/// The account endpoints the sign-in sheet needs besides signing in itself.
struct AccountAPI: Sendable {
    let client: any HTTPClient

    /// `POST /auth/email-status` (public, rate limited): whether this email has
    /// an account. Decides between the password step and the create step. A reply
    /// without `exists` is an error, never "new".
    func status(ofEmail email: String) async throws -> AccountStatus {
        let reply: StatusReply = try await client.send(
            .post("auth/email-status", body: EmailBody(email: email))
        )
        return reply.exists ? .hasAccount : .newEmail
    }

    /// `POST /auth/sign-up` (public): makes the account and records that the person
    /// agreed to how their details are kept. A 409 is `AuthError.emailAlreadyExists`;
    /// a reply without `verificationRequired` is an error.
    func signUp(
        name: String,
        email: String,
        password: String,
        hasAgreed: Bool
    ) async throws -> SignUpResult {
        do {
            let reply: SignUpReply = try await client.send(
                .post(
                    "auth/sign-up",
                    body: SignUpBody(
                        name: name,
                        email: email,
                        password: password,
                        hasAgreed: hasAgreed
                    )
                )
            )
            return reply.verificationRequired ? .needsEmailVerification : .created
        } catch let error as NetworkError where error.statusCode == 409 {
            throw AuthError.emailAlreadyExists
        }
    }

    /// `POST /auth/forgot-password` (public): emails a reset link. The reply is
    /// the same whether or not the address has an account.
    func sendResetLink(toEmail email: String) async throws {
        _ = try await client.send(.post("auth/forgot-password", body: EmailBody(email: email)))
    }

    /// `POST /auth/send-verification` (public): sends the verification link again.
    func sendVerificationLink(toEmail email: String) async throws {
        _ = try await client.send(.post("auth/send-verification", body: EmailBody(email: email)))
    }

    /// `GET /auth/welcome-photos` (public): the pictures on the sign-in sheet.
    /// Optional: the sheet works without them.
    func welcomePhotos() async throws -> [URL] {
        let reply: PhotosReply = try await client.send(.get("auth/welcome-photos"))
        return (reply.photos ?? []).compactMap(URL.init(string:))
    }

    private struct EmailBody: Encodable {
        var email: String
    }

    private struct SignUpBody: Encodable {
        var name: String
        var email: String
        var password: String
        var hasAgreed: Bool
    }

    private struct StatusReply: Decodable {
        var exists: Bool
    }

    private struct SignUpReply: Decodable {
        var verificationRequired: Bool
    }

    private struct PhotosReply: Decodable {
        var photos: [String]?
    }
}
