@testable import Crossdrive
import DataLayer
import XCTest

let pledgeJSON = """
{"reference": "CD-0142", "gcashNumber": "0917 123 4567", "accountName": "CrossDrive Missions",
 "bankName": "BPI", "bankAccount": "1234 5678 90"}
"""

/// The school fund (or another kind) and a giving model over a stubbed server,
/// shared by the giving tests.
@MainActor
protocol GiveTestRig {}

@MainActor
extension GiveTestRig {
    func ministry(kind: Ministry.Kind = .school) -> Ministry {
        Ministry(
            id: "school-fund",
            name: "School fund",
            schedule: nil,
            place: "Gatbo and Bacon",
            summary: "",
            imageURL: nil,
            kind: kind,
            fund: kind == .school ? Ministry.Fund(
                kidsPaid: 12,
                kidsGoal: 20,
                raised: Money(amountMinor: 9_600_000, currency: "PHP"),
                goal: Money(amountMinor: 16_000_000, currency: "PHP"),
                costs: [
                    .init(title: "School fees", amount: Money(amountMinor: 45000, currency: "PHP")),
                    .init(
                        title: "Jeepney fare",
                        amount: Money(amountMinor: 25000, currency: "PHP")
                    ),
                    .init(title: "Notebooks", amount: Money(amountMinor: 10000, currency: "PHP")),
                ]
            ) : nil
        )
    }

    func makeViewModel(
        ministry: Ministry? = nil,
        userName: String? = nil,
        signIn: SignInSpy? = nil,
        guest: GuestFlag? = nil,
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse = { _ in
            .json(pledgeJSON)
        }
    ) -> GiveViewModel {
        GiveViewModel(
            ministry: ministry ?? self.ministry(),
            api: MinistriesAPI(client: StubHTTPClient(handler)),
            userName: { userName },
            needsSignIn: { guest?.isGuest ?? signIn.map { !$0.isSignedIn } ?? false },
            makeSignIn: signIn.map { spy in { spy.make(reminder: $0, isWanted: $1, then: $2) } }
        )
    }
}

/// Whether the person is a guest right now, for a test to change.
@MainActor
final class GuestFlag {
    var isGuest = true
}

/// Stands in for the coordinator's sign-in screen: keeps what it was given so
/// the test can finish the sign-in when it likes.
@MainActor
final class SignInSpy {
    private(set) var reminder: GateTrip?
    /// True once a sign-in has gone through.
    private(set) var isSignedIn = false
    private var isWanted: (@MainActor () -> Bool)?
    private var then: (@MainActor () async -> Void)?

    func make(
        reminder: GateTrip,
        isWanted: @escaping @MainActor () -> Bool,
        then: @escaping @MainActor () async -> Void
    ) -> EntryViewModel {
        self.reminder = reminder
        self.isWanted = isWanted
        self.then = then
        return makeEntryRig(trip: reminder).viewModel
    }

    /// Finishes the sign-in as the coordinator does: only while it is still wanted.
    /// Returns whether it went on.
    @discardableResult
    func finish() async -> Bool {
        guard isWanted?() == true else { return false }
        isSignedIn = true
        await then?()
        return true
    }
}
