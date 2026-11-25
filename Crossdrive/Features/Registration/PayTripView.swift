import DesignSystem
import Photos
import SwiftUI

/// "Pay for the trip". The app never takes the payment:
/// it shows CrossDrive's own QR code, the amount and the message to write,
/// and records "I've sent it" for a coordinator to check.
struct PayTripView: View {
    @State private var viewModel: PayTripViewModel
    private let onDone: () -> Void

    @State private var showsGCash = false

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    private static let qrSide: CGFloat = 118

    init(viewModel: PayTripViewModel, onDone: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onDone = onDone
    }

    private var event: Event {
        viewModel.detail.event
    }

    private var feeText: String {
        event.fee?.formatted ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Pay for the trip")
                    .textRole(.title1, emphasized: true)
                    .accessibilityAddTraits(.isHeader)
                feeCard
                if viewModel.progress == .sent {
                    sentNote
                }
                if viewModel.showsHowToPay, viewModel.progress != .paid {
                    howToPay
                }
            }
            .screenMargins()
            .padding(.bottom, 24)
            .animation(DesignSystem.Motion.enter, value: viewModel.progress)
            .animation(DesignSystem.Motion.enter, value: viewModel.showsHowToPay)
        }
        .background(theme.background)
        .safeAreaInset(edge: .bottom, spacing: 0) { buttons }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadQR(maxPixels: Int(Self.qrSide * displayScale)) }
        .dsToast($viewModel.toast)
        .sensoryFeedback(.success, trigger: viewModel.progress) { _, progress in progress == .sent }
    }

    // MARK: - Fee and progress

    private var feeCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(feeText).textRole(.largeTitle, emphasized: true)
                Spacer()
                Text(viewModel.progress == .paid ? "Paid" : "Before \(event.feeDueDateLabel)")
                    .textRole(.footnote, emphasized: true)
                    .foregroundStyle(CDColor.onHarvest)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(CDColor.harvest, in: DesignSystem.Radius.shape(4))
            }
            Text("Trip fee for the \(event.title)")
                .textRole(.subheadline)
                .foregroundStyle(theme.labelSecondary)
            tracker.padding(.top, 16)
        }
        .padding(16)
        .background(theme.surface, in: DesignSystem.Radius.shape(18))
        .overlay { DesignSystem.Radius.shape(18).strokeBorder(theme.border, lineWidth: 1) }
    }

    private var tracker: some View {
        let stops: [(PayTripViewModel.Progress, LocalizedStringKey)] = [
            (.toPay, "Pay"),
            (.sent, "Sent"),
            (.paid, "Paid"),
        ]
        return CDStepRow(
            titles: [
                String(localized: "Pay"),
                String(localized: "Sent"),
                String(localized: "Paid"),
            ],
            current: stops.firstIndex { $0.0 == viewModel.progress } ?? 0
        )
        .accessibilityLabel(Text(progressLabel))
    }

    private var progressLabel: String {
        switch viewModel.progress {
        case .toPay: String(localized: "Payment status: not paid")
        case .sent: String(localized: "Payment status: sent, waiting for a coordinator")
        case .paid: String(localized: "Payment status: paid")
        }
    }

    private var sentNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("We got your note").textRole(.headline, emphasized: true)
            Text("""
            A coordinator is checking for your \(feeText). This usually takes a day. \
            We'll tell you here when it's done.
            """)
            .textRole(.subheadline)
            .foregroundStyle(theme.labelSecondary)
            if !viewModel.showsHowToPay {
                Button("Show how to pay again") { viewModel.showHowToPayAgain() }
                    .registrationLink()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.surface, in: DesignSystem.Radius.shape(18))
        .overlay { DesignSystem.Radius.shape(18).strokeBorder(theme.border, lineWidth: 1) }
    }

    // MARK: - How to pay

    @ViewBuilder private var howToPay: some View {
        if viewModel.detail.pay?.qrURL != nil {
            qrCard
        }
        VStack(spacing: 0) {
            copyRow(label: "Amount", value: feeText)
            if let reference = viewModel.registration.reference {
                Divider().overlay(theme.separator)
                copyRow(label: "Message", value: reference)
            }
            if showsGCash, let gcash = viewModel.detail.pay?.gcashNumber {
                Divider().overlay(theme.separator)
                copyRow(label: "GCash number", value: gcash)
            }
        }
        .background(theme.surface, in: DesignSystem.Radius.shape(18))
        .overlay { DesignSystem.Radius.shape(18).strokeBorder(theme.border, lineWidth: 1) }
        if viewModel.detail.pay?.gcashNumber != nil, !showsGCash {
            Button("No QR? Send to our GCash number") { showsGCash = true }
                .registrationLink()
        }
    }

    private var qrCard: some View {
        HStack(alignment: .center, spacing: 14) {
            qrImage
            VStack(alignment: .leading, spacing: 4) {
                Text("Scan to pay").textRole(.headline, emphasized: true)
                Text("Open GCash, Maya or your bank app and scan this QR Ph code.")
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
                if viewModel.qrImage != nil {
                    Button("Save to Photos") { Task { await saveQR() } }
                        .registrationLink()
                }
            }
        }
        .padding(14)
        .background(theme.surface, in: DesignSystem.Radius.shape(18))
        .overlay { DesignSystem.Radius.shape(18).strokeBorder(theme.border, lineWidth: 1) }
    }

    /// The QR code, or a shimmering square of the same size while it loads.
    private var qrImage: some View {
        Group {
            if let image = viewModel.qrImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .accessibilityLabel(Text("CrossDrive's QR Ph code"))
            } else if viewModel.isLoadingQR {
                theme.surfacePressed.dsLoading(true)
            } else {
                theme.surfacePressed
                    .overlay {
                        Text("The QR code didn't load.")
                            .textRole(.caption1)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.labelSecondary)
                            .padding(6)
                    }
            }
        }
        .frame(width: Self.qrSide, height: Self.qrSide)
        .clipShape(DesignSystem.Radius.shape(12))
        .overlay { DesignSystem.Radius.shape(12).strokeBorder(theme.border, lineWidth: 1) }
    }

    private func copyRow(label: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).textRole(.footnote).foregroundStyle(CDColor.captionMuted)
                Text(value).textRole(.headline, emphasized: true).textSelection(.enabled)
            }
            Spacer()
            Button("Copy") {
                UIPasteboard.general.string = value
                viewModel.toast = .success(String(localized: "Copied"))
            }
            .registrationLink()
            .accessibilityLabel(Text("Copy \(Text(label))"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Buttons

    private var buttons: some View {
        VStack(spacing: 4) {
            if viewModel.progress == .toPay {
                Button("I've sent it") { Task { await viewModel.markSent() } }
                    .buttonStyle(.ds(.primary, isLoading: viewModel.isSending))
                Button("Pay later") { dismiss() }
                    .buttonStyle(.ds(.plain))
            } else {
                Button("Done", action: onDone)
                    .buttonStyle(.ds(.primary))
            }
        }
        .screenMargins()
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    /// Adds the QR code to Photos. Needs add-only access, asked here when the
    /// person taps the button, never at launch.
    private func saveQR() async {
        guard let image = viewModel.qrImage else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            viewModel
                .toast =
                .error(
                    String(localized: "Allow Crossdrive to add photos in Settings, then try again.")
                )
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            viewModel.toast = .success(String(localized: "Saved to Photos"))
        } catch {
            viewModel.toast = .error(String(localized: "Couldn't save the QR code. Try again."))
        }
    }
}
