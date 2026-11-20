import Foundation

/// An amount in the smallest unit (centavos) and its currency.
struct Money: Hashable, Sendable {
    let amountMinor: Int
    let currency: String

    /// "₱1,500", or "₱1,500.50" when there are centavos.
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_PH")
        formatter.currencyCode = currency
        formatter.currencySymbol = currency == "PHP" ? "₱" : formatter.currencySymbol
        formatter.maximumFractionDigits = amountMinor % 100 == 0 ? 0 : 2
        formatter.minimumFractionDigits = formatter.maximumFractionDigits
        return formatter.string(from: NSNumber(value: Double(amountMinor) / 100)) ?? ""
    }
}
