import DataLayer
import Foundation

extension MinistriesAPI {
    /// `POST /ministries/{id}/pledges` (signed in): saves a pledge and returns
    /// its reference and where to send the money. The same `idempotencyKey` on a
    /// retry after a timeout never saves it twice. The app never takes a payment.
    func pledge(
        _ gift: Gift,
        ministry: Ministry.ID,
        idempotencyKey: String
    ) async throws -> Pledge {
        let reply: PledgeReplyDTO = try await client.send(
            .post(
                "ministries/\(Self.pathSegment(ministry))/pledges",
                body: PledgeBody(
                    frequency: gift.frequency.rawValue,
                    amountMinor: gift.amount.amountMinor,
                    currency: gift.amount.currency
                ),
                headers: ["Idempotency-Key": idempotencyKey]
            )
        )
        guard let reference = reply.reference, !reference.isEmpty,
              let gcash = reply.gcashNumber, !gcash.isEmpty
        else { throw NetworkError.invalidResponse }
        let bank = reply.bankName.flatMap { name in
            reply.bankAccount.map { Pledge.Bank(name: name, account: $0) }
        }
        return Pledge(
            reference: reference,
            gcashNumber: gcash,
            accountName: reply.accountName ?? "CrossDrive Missions",
            bank: bank
        )
    }

    /// `POST /pledges/{reference}/sent` (signed in): the person says they sent
    /// the first gift. Someone at CrossDrive confirms it once it arrives.
    func markGiftSent(reference: String, remindMonthly: Bool) async throws {
        _ = try await client.send(
            .post(
                "pledges/\(Self.pathSegment(reference))/sent",
                body: SentBody(remind: remindMonthly)
            )
        )
    }
}

private struct PledgeBody: Encodable {
    var frequency: String
    var amountMinor: Int
    var currency: String
}

private struct SentBody: Encodable {
    var remind: Bool
}

private struct PledgeReplyDTO: Decodable {
    var reference: String?
    var gcashNumber: String?
    var accountName: String?
    var bankName: String?
    var bankAccount: String?
}
