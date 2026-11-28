import DataLayer
import DesignSystem
import Foundation
import Observation

/// Giving to a ministry: pick an amount, sign in if a guest, save the pledge,
/// send the first gift by GCash or bank, then a thank-you. The app never takes
/// a payment; CrossDrive confirms it.
@Observable @MainActor
final class GiveViewModel: Identifiable {
    enum Step: Hashable {
        case amount
        case signIn
        case pledge
        case thanks
    }

    static let minimumPesos = 300
    /// Kids go to school for ten months a year.
    static let schoolMonths = 10
    private static let monthlyPresets = [300, 500, 800, 1200]

    let ministry: Ministry
    private(set) var step: Step = .amount
    private(set) var frequency: Gift.Frequency = .monthly
    private(set) var pesos = 800
    private(set) var pledge: Pledge?
    /// The sign-in screen while a guest is on that step.
    private(set) var signIn: EntryViewModel?
    private(set) var isSending = false
    var remindMonthly = true
    var paysByBank = false
    var toast: DSToast?
    /// Set by the screen from the connection; saving waits for one.
    var isOnline = true

    private let api: MinistriesAPI
    private let userName: () -> String?
    /// Builds the sign-in screen for a guest; `nil` when the person is signed in
    /// as the sheet opens. `isWanted` says whether the person is still on that
    /// step; `then` runs once the sign-in has worked.
    private let makeSignIn: SignInMaker?
    private var hasSignedIn = false
    /// The sign-in the person is on now; Back or Cancel clears it.
    private var signInAttempt: UUID?
    /// One per gift, so a retry after a timeout never saves two pledges, and a
    /// changed amount is never answered with the pledge saved for the old one.
    private var idempotencyKey = UUID().uuidString
    private var keyedGift: Gift?

    typealias SignInMaker = (
        _ reminder: GateTrip,
        _ isWanted: @escaping @MainActor () -> Bool,
        _ then: @escaping @MainActor () async -> Void
    ) -> EntryViewModel

    init(
        ministry: Ministry,
        api: MinistriesAPI,
        userName: @escaping () -> String?,
        makeSignIn: SignInMaker? = nil
    ) {
        self.ministry = ministry
        self.api = api
        self.userName = userName
        self.makeSignIn = makeSignIn
    }

    // MARK: - Amount

    var frequencies: [Gift.Frequency] {
        ministry.kind == .school ? [.monthly, .yearly] : Gift.Frequency.allCases
    }

    var presets: [Int] {
        frequency == .yearly ? Self.monthlyPresets.map { $0 * Self.schoolMonths } : Self
            .monthlyPresets
    }

    var gift: Gift {
        Gift(frequency: frequency, pesos: pesos)
    }

    /// "a month", "a year", or nothing for one gift.
    var frequencyLabel: String? {
        switch frequency {
        case .monthly: String(localized: "a month")
        case .yearly: String(localized: "a year")
        case .once: nil
        }
    }

    /// Switching to yearly multiplies by ten, and back divides, so the gift keeps its size.
    func setFrequency(_ new: Gift.Frequency) {
        guard new != frequency else { return }
        if new == .yearly {
            pesos *= Self.schoolMonths
        } else if frequency == .yearly {
            pesos = max(pesos / Self.schoolMonths, Self.minimumPesos)
        }
        frequency = new
    }

    func choose(_ amount: Int) {
        pesos = max(amount, Self.minimumPesos)
    }

    /// The Change field: whole pesos from the minimum. Returns `false` and keeps
    /// the amount when the text isn't one.
    func setCustomAmount(_ text: String) -> Bool {
        let cleaned = text.filter { !$0.isWhitespace && $0 != "," && $0 != "₱" }
        guard let amount = Int(cleaned), amount >= Self.minimumPesos, amount <= 10_000_000
        else { return false }
        pesos = amount
        return true
    }

    /// What the gift comes to over a school year.
    private var yearMinor: Int {
        gift.amount.amountMinor * (frequency == .monthly ? Self.schoolMonths : 1)
    }

    /// "₱800 for 10 months is ₱8,000, one kid's school year." School fund only.
    var yearLine: String? {
        guard ministry.kind == .school,
              let kidMonth = ministry.fund?.kidMonthMinor else { return nil }
        let kidYear = kidMonth * Self.schoolMonths
        let share = if yearMinor < kidYear {
            String(localized: "part of one kid's school year")
        } else if yearMinor == kidYear {
            String(localized: "one kid's school year")
        } else {
            String(localized: "more than one kid's school year")
        }
        let total = Money(amountMinor: yearMinor, currency: "PHP").formatted
        switch frequency {
        case .monthly:
            return String(
                localized: "\(gift.amount.formatted) for 10 months is \(total), \(share)."
            )
        case .yearly, .once:
            return String(localized: "\(total) is \(share).")
        }
    }

    /// How much of the fund's goal this gift adds over a year, up to what is left.
    var giftFraction: Double {
        guard let fund = ministry.fund, let goal = fund.goal, goal.amountMinor > 0 else { return 0 }
        return min(Double(yearMinor) / Double(goal.amountMinor), 1 - fund.fraction)
    }

    // MARK: - Steps

    /// Only a guest sees a step row: someone signed in has just the amount and
    /// the pledge, with nothing to count.
    var showsSteps: Bool {
        makeSignIn != nil
    }

    /// A guest sees Sign in for the whole sheet, even after signing in, so the
    /// row never jumps.
    var stepTitles: [String] {
        makeSignIn == nil
            ? [String(localized: "Amount"), String(localized: "Pledge")]
            : [
                String(localized: "Amount"),
                String(localized: "Sign in"),
                String(localized: "Pledge"),
            ]
    }

    var stepIndex: Int {
        switch step {
        case .amount: 0
        case .signIn: 1
        case .pledge, .thanks: stepTitles.count - 1
        }
    }

    /// Continue on the amount: a guest signs in first, anyone else saves the pledge.
    func continueTapped() async {
        guard step == .amount, !isSending else { return }
        if let makeSignIn, !hasSignedIn {
            let attempt = UUID()
            signInAttempt = attempt
            signIn = makeSignIn(
                reminder,
                { [weak self] in self?.step == .signIn && self?.signInAttempt == attempt },
                { [weak self] in await self?.signedIn() }
            )
            step = .signIn
        } else {
            await savePledge()
        }
    }

    /// Back or Cancel on the sign-in step: the amount stays as it was.
    func backToAmount() {
        guard step == .signIn else { return }
        signInAttempt = nil
        signIn = nil
        step = .amount
    }

    /// "₱800 a month" and the ministry, shown on the sign-in screen.
    private var reminder: GateTrip {
        GateTrip(
            title: [gift.amount.formatted, frequencyLabel].compactMap(\.self)
                .joined(separator: " "),
            detail: ministry.name,
            imageURL: ministry.heroURL,
            purpose: .give(steps: stepTitles)
        )
    }

    private func signedIn() async {
        guard step == .signIn else { return }
        hasSignedIn = true
        signInAttempt = nil
        signIn = nil
        step = .amount
        await savePledge()
    }

    /// Saves the pledge once, even if Continue is tapped twice.
    private func savePledge() async {
        guard !isSending, step == .amount else { return }
        guard isOnline else {
            toast = .info(String(localized: "Connect to the internet to save your pledge."))
            return
        }
        if keyedGift != gift {
            idempotencyKey = UUID().uuidString
            keyedGift = gift
        }
        isSending = true
        defer { isSending = false }
        do {
            pledge = try await api.pledge(
                gift,
                ministry: ministry.id,
                idempotencyKey: idempotencyKey
            )
            step = .pledge
        } catch {
            toast = .error(String(localized: "Couldn't save your pledge. Try again."))
        }
    }

    /// "I've sent it": tells CrossDrive to look for the gift, then says thanks.
    func markSent() async {
        guard !isSending, step == .pledge, let pledge else { return }
        guard isOnline else {
            toast = .info(String(localized: "Connect to the internet to tell us you sent it."))
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            try await api.markGiftSent(
                reference: pledge.reference,
                remindMonthly: frequency == .monthly && remindMonthly
            )
            step = .thanks
        } catch {
            toast = .error(String(localized: "Couldn't save. Try again."))
        }
    }

    // MARK: - Copy

    /// "Your pledge is saved. It starts when we get your first ₱800."
    var pledgeLead: String {
        frequency == .once
            ?
            String(
                localized: "Your pledge is saved. We'll confirm it when we get your \(gift.amount.formatted)."
            )
            :
            String(
                localized: "Your pledge is saved. It starts when we get your first \(gift.amount.formatted)."
            )
    }

    /// "Salamat, Joy", or "Salamat" without a name.
    var thanksTitle: String {
        let first = userName()?.split(separator: " ").first.map(String.init)
        return first.map { String(localized: "Salamat, \($0)") } ?? String(localized: "Salamat")
    }

    var thanksMessage: String {
        let gift = [gift.amount.formatted, frequencyLabel].compactMap(\.self).joined(separator: " ")
        if ministry.kind == .school {
            let place = ministry.place.map { String(localized: " in \($0)") } ?? ""
            return String(localized: """
            Your \(gift) helps one more kid\(place) stay in school this year. \
            We'll send you how the kids are doing after each quarter.
            """)
        }
        return String(localized: """
        Your \(gift) helps \(ministry.name). We'll send you how it's going after each quarter.
        """)
    }

    var waitingLine: String {
        frequency == .once
            ? String(localized: "Waiting for your \(gift.amount.formatted).")
            : String(localized: "Waiting for your first \(gift.amount.formatted).")
    }
}
