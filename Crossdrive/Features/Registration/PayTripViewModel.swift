import DataLayer
import DesignSystem
import Observation
import UIKit

/// How to pay a trip's fee outside the app: CrossDrive's own
/// QR code and GCash number from the server, the amount and the message to
/// write. The person says when they sent it; a coordinator marks it paid.
@Observable @MainActor
final class PayTripViewModel {
    enum Progress: Equatable {
        case toPay
        case sent
        case paid
    }

    let detail: EventDetail
    let registration: RegistrationResult
    private(set) var progress: Progress
    /// The QR code, decoded at the size shown; `nil` until it has loaded.
    private(set) var qrImage: UIImage?
    private(set) var isLoadingQR: Bool
    private(set) var isSending = false
    var toast: DSToast?

    private let api: EventsAPI
    private let imageLoader: any ImageLoading

    init(
        detail: EventDetail,
        registration: RegistrationResult,
        api: EventsAPI,
        imageLoader: any ImageLoading
    ) {
        self.detail = detail
        self.registration = registration
        self.api = api
        self.imageLoader = imageLoader
        progress = detail.registration?.isPaid == true ? .paid : .toPay
        isLoadingQR = detail.pay?.qrURL != nil
    }

    /// Loads the QR code once, at the size the screen shows it.
    func loadQR(maxPixels: Int) async {
        guard qrImage == nil, let url = detail.pay?.qrURL else {
            isLoadingQR = false
            return
        }
        qrImage = await imageLoader.image(for: url, maxPixels: maxPixels)
        isLoadingQR = false
    }

    /// "I've sent it". A second tap while the first is out sends nothing more.
    func markSent() async {
        guard !isSending, progress == .toPay else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await api.markPaymentSent(registrationID: registration.id)
            progress = .sent
        } catch {
            toast = .error(error.userMessage)
        }
    }

    /// After "I've sent it", the steps hide behind "Show how to pay again".
    private(set) var isShowingHowToPayAgain = false

    /// The QR code, amount and message are on screen.
    var showsHowToPay: Bool {
        progress == .toPay || isShowingHowToPayAgain
    }

    func showHowToPayAgain() {
        isShowingHowToPayAgain = true
    }
}
