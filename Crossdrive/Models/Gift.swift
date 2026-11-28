import Foundation

/// What someone pledges to give to a ministry, in whole pesos.
struct Gift: Hashable, Sendable {
    enum Frequency: String, CaseIterable, Sendable {
        case monthly
        case yearly
        case once
    }

    var frequency: Frequency
    var pesos: Int

    var amount: Money {
        Money(amountMinor: pesos * 100, currency: "PHP")
    }
}

/// A saved pledge: the gift the server saved, the reference to type in the
/// payment message, and where to send it.
struct Pledge: Hashable, Sendable {
    let reference: String
    /// What the server saved. A retry after a timeout can be answered with the
    /// pledge first saved, so this, not what is on screen, is what to send.
    var gift: Gift
    var gcashNumber: String
    var accountName: String
    /// `nil` when the server offers no bank transfer.
    var bank: Bank?

    struct Bank: Hashable, Sendable {
        var name: String
        var account: String
    }
}
