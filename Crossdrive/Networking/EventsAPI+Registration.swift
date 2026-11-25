import DataLayer
import Foundation

extension EventsAPI {
    /// `POST /events/{id}/registrations` (signed in): joins the trip or camp, or
    /// its waiting list. The same `idempotencyKey` on a retry after a timeout
    /// never registers twice. A 409 means the last slot was just taken.
    func register(
        eventID: Event.ID,
        form: RegistrationForm,
        kind: EventKind,
        waitlist: Bool,
        idempotencyKey: String
    ) async throws -> RegistrationResult {
        let reply: RegistrationReplyDTO = try await client.send(
            .post(
                "events/\(Self.pathSegment(eventID))/registrations",
                body: RegistrationBody(form: form, kind: kind, waitlist: waitlist),
                headers: ["Idempotency-Key": idempotencyKey]
            )
        )
        guard let id = reply.id, !id.isEmpty else { throw NetworkError.invalidResponse }
        return RegistrationResult(
            id: id,
            status: reply.status == "waitlisted" ? .waitlisted : .pending,
            reference: reply.reference.flatMap { $0.isEmpty ? nil : $0 },
            isPermitWaiting: reply.permit == "waiting"
        )
    }

    /// `POST /me/registrations/{id}/payment-sent` (signed in): the person says
    /// they sent the fee. A coordinator marks it paid once it arrives; the app
    /// never takes or checks a payment.
    func markPaymentSent(registrationID: String) async throws {
        _ = try await client.send(
            .post(
                "me/registrations/\(Self.pathSegment(registrationID))/payment-sent",
                body: EmptyBody()
            )
        )
    }
}

private struct EmptyBody: Encodable {}

private struct RegistrationReplyDTO: Decodable {
    var id: String?
    var status: String?
    var reference: String?
    var permit: String?
}

/// Numbers go up as "09…" whatever the person typed; empty optional text is left out.
private struct RegistrationBody: Encodable {
    var role: String?
    var phone: String
    var messenger: String?
    var isMinor: Bool
    var emergencyName: String
    var emergencyPhone: String
    var notes: String?
    var signature: String
    var guardianName: String?
    var guardianPhone: String?
    var waitlist: Bool

    init(form: RegistrationForm, kind: EventKind, waitlist: Bool) {
        switch form.role {
        case .anywhere: role = "anywhere"
        case let .team(id): role = id
        case nil: role = nil
        }
        phone = PhilippineMobile.normalized(form.mobile) ?? form.mobile
        messenger = form.messengerName.nonEmpty
        isMinor = kind == .trip && form.isMinor
        emergencyName = form.emergencyName.trimmingCharacters(in: .whitespacesAndNewlines)
        emergencyPhone = PhilippineMobile.normalized(form.emergencyMobile) ?? form.emergencyMobile
        notes = form.notes.nonEmpty
        signature = form.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        guardianName = form.guardianName.nonEmpty
        guardianPhone = form.guardianMobile.nonEmpty.map { PhilippineMobile.normalized($0) ?? $0 }
        self.waitlist = waitlist
    }
}

private extension String {
    var nonEmpty: String? {
        let text = trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
