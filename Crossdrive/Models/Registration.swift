import Foundation

/// One step of joining a trip or a camp. A camper joins the camp's program, so
/// a camp has no role step.
enum RegistrationStep: Hashable, Sendable {
    case role
    case details
    case waiver
    case done

    static func steps(for kind: EventKind) -> [RegistrationStep] {
        switch kind {
        case .trip: [.role, .details, .waiver, .done]
        case .camp: [.details, .waiver, .done]
        }
    }

    /// The step's name under its number, and on the Back button of the step after it.
    var title: String {
        switch self {
        case .role: String(localized: "Role")
        case .details: String(localized: "Details")
        case .waiver: String(localized: "Waiver")
        case .done: String(localized: "Done")
        }
    }
}

/// What a person fills in to join. Everything stays as typed until it is sent,
/// so going back a step or a failed send never loses anything.
struct RegistrationForm: Equatable, Sendable {
    enum Role: Hashable, Sendable {
        /// "Wherever I'm needed": the coordinators place them on the day.
        case anywhere
        case team(EventRole.ID)
    }

    enum Field: Hashable, Sendable {
        case role, mobile, emergencyName, emergencyMobile, signature, guardianName, guardianMobile
    }

    var role: Role?
    var mobile = ""
    var messengerName = ""
    var isMinor = false
    var emergencyName = ""
    var emergencyMobile = ""
    var notes = ""
    var signature = ""
    var guardianName = ""
    var guardianMobile = ""

    /// A minor on a trip needs a parent or guardian; on a camp the permit is
    /// optional (camps are for adults).
    func needsGuardian(for kind: EventKind) -> Bool {
        kind == .trip && isMinor
    }

    /// The problems on one step, by field. Empty means the step can go on.
    func errors(on step: RegistrationStep, kind: EventKind) -> [Field: String] {
        var errors: [Field: String] = [:]
        switch step {
        case .role:
            if role == nil {
                errors[.role] = String(localized: "Pick a team, or Wherever I'm needed.")
            }
        case .details:
            errors[.mobile] = PhilippineMobile.problem(with: mobile)
            if emergencyName.trimmed.isEmpty {
                errors[.emergencyName] = String(localized: "Enter who we should call.")
            }
            errors[.emergencyMobile] = PhilippineMobile.problem(with: emergencyMobile)
        case .waiver:
            if signature.trimmed.isEmpty {
                errors[.signature] = String(localized: "Type your full name to sign the waiver.")
            }
            let hasGuardian = !guardianName.trimmed.isEmpty || !guardianMobile.trimmed.isEmpty
            if needsGuardian(for: kind) || hasGuardian {
                if guardianName.trimmed.isEmpty {
                    errors[.guardianName] =
                        String(localized: "Enter your parent or guardian's name.")
                }
                errors[.guardianMobile] = PhilippineMobile.problem(with: guardianMobile)
            }
        case .done:
            break
        }
        return errors
    }
}

/// What the server made of a registration.
struct RegistrationResult: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        /// Waiting for a coordinator to confirm.
        case pending
        case waitlisted
    }

    let id: String
    var status: Status
    /// The code a person writes in the payment message ("CD-0187").
    var reference: String?
    /// A parent or guardian was texted a permit and hasn't signed yet.
    var isPermitWaiting: Bool
}

/// A Philippine mobile number: 11 digits starting with 09. "+63 917…" and
/// spaces or dashes are accepted and stored as "0917…".
enum PhilippineMobile {
    static func normalized(_ text: String) -> String? {
        var digits = text.filter(\.isNumber)
        if digits.hasPrefix("63"), digits.count == 12 {
            digits = "0" + digits.dropFirst(2)
        }
        guard digits.count == 11, digits.hasPrefix("09") else { return nil }
        return digits
    }

    /// What is wrong with the number, in the person's words; `nil` when it is fine.
    static func problem(with text: String) -> String? {
        if normalized(text) != nil {
            return nil
        }
        let digits = text.filter(\.isNumber)
        if digits.isEmpty {
            return String(localized: "Enter a mobile number.")
        }
        if digits.hasPrefix("63") || digits.hasPrefix("09") || digits == "0" {
            let wanted = digits.hasPrefix("63") ? 12 : 11
            if digits.count < wanted {
                return String(
                    localized: "This number is too short. Enter all 11 digits, starting with 09."
                )
            }
            return String(localized: "This number is too long. Enter 11 digits, starting with 09.")
        }
        return String(localized: "Enter a mobile number that starts with 09.")
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
