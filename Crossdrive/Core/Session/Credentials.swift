/// What the sign-in form collects. Never logged.
struct Credentials: Sendable, Equatable {
    let email: String
    let password: String
}
