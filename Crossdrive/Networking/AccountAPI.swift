import DataLayer
import Foundation

/// The account endpoints the sign-in sheet needs besides signing in itself.
struct AccountAPI: Sendable {
    let client: any HTTPClient

    /// `POST /auth/sign-up` (public): makes the account and records that the person
    /// agreed to how their details are kept. The reply must not tell whether the
    /// email already had an account: the server answers the same either way and
    /// emails the owner. A 409 is read as that same answer, so the app never
    /// shows the difference. A reply without `verificationRequired` is an error.
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
            return .needsEmailVerification
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

    private struct EmailBody: Encodable {
        var email: String
    }

    private struct SignUpBody: Encodable {
        var name: String
        var email: String
        var password: String
        var hasAgreed: Bool
    }

    private struct SignUpReply: Decodable {
        var verificationRequired: Bool
    }
}
