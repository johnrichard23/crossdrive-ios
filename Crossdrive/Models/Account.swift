import Foundation

/// What happened after an account was made.
enum SignUpResult: Equatable, Sendable {
    /// Ready to use: the app signs the person in.
    case created
    /// The server sent a link and wants the email checked first.
    case needsEmailVerification
}

/// The trip a guest was looking at when they were asked to sign in, so the
/// sheet can remind them what they are joining.
struct GateTrip: Equatable, Sendable {
    /// What the person was about to do, for the sign-in sheet's words.
    enum Purpose: Equatable, Sendable {
        case joinTrip
        /// Giving, inside the giving sheet; `steps` is its step row.
        case give(steps: [String])
    }

    var title: String
    /// "Dec 12 to 14 · Behia, Bagatao Island".
    var detail: String
    var imageURL: URL?
    var purpose: Purpose = .joinTrip
}

extension Event {
    /// The reminder shown on the sign-in sheet.
    var gateTrip: GateTrip {
        let parts = [dateRangeLabel, place].compactMap(\.self).filter { !$0.isEmpty }
        return GateTrip(
            title: title,
            detail: parts.joined(separator: " · "),
            imageURL: heroImageURL
        )
    }
}
