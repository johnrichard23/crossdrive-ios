/// Whether someone is signed in. A guest is `signedOut`.
enum SessionState: Sendable, Equatable {
    case signedOut
    case signedIn(AppUser)

    var user: AppUser? {
        if case let .signedIn(user) = self {
            user
        } else {
            nil
        }
    }
}
