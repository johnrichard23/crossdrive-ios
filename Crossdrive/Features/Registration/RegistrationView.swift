import DataLayer
import DesignSystem
import SwiftUI

/// Joining a trip or a camp: a large sheet with its own steps. Cancel asks
/// first once anything is typed.
struct RegistrationView: View {
    @State private var viewModel: RegistrationViewModel
    /// `true` when the person registered, so Trip detail reloads.
    private let onClose: (_ registered: Bool) -> Void

    @State private var isConfirmingCancel = false
    @State private var payViewModel: PayTripViewModel?

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline

    init(viewModel: RegistrationViewModel, onClose: @escaping (_ registered: Bool) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        CDStepRow(
                            titles: viewModel.steps.map(\.title),
                            current: viewModel.stepIndex
                        )
                        .id(Self.top)
                        stepContent
                            .id(viewModel.step)
                            .transition(.opacity)
                    }
                    .screenMargins()
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                // Each step starts at its top, not where the last one was scrolled to.
                .onChange(of: viewModel.stepIndex) { scroller.scrollTo(Self.top, anchor: .top) }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(theme.background)
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomButton }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .navigationDestination(item: $payViewModel) { model in
                PayTripView(viewModel: model, onDone: { onClose(true) })
            }
            .animation(DesignSystem.Motion.enter, value: viewModel.stepIndex)
            .sensoryFeedback(.success, trigger: viewModel.isDone) { _, isDone in isDone }
            .confirmationDialog(
                "Leave without registering?",
                isPresented: $isConfirmingCancel,
                titleVisibility: .visible
            ) {
                Button("Leave", role: .destructive) { onClose(false) }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("What you typed won't be saved.")
            }
        }
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges || viewModel.sendState == .sending)
        // Medical notes, phone numbers and the payment QR stay out of the app switcher.
        .privacyCover()
    }

    private static let top = "top"

    private var title: String {
        viewModel.detail.event.kind == .camp
            ? String(localized: "Register for the camp")
            : String(localized: "Join the trip")
    }

    // MARK: - Steps

    @ViewBuilder private var stepContent: some View {
        switch viewModel.step {
        case .role:
            RegistrationRoleStep(viewModel: viewModel)
        case .details:
            RegistrationDetailsStep(viewModel: viewModel)
        case .waiver:
            RegistrationWaiverStep(viewModel: viewModel)
        case .done:
            RegistrationDoneStep(viewModel: viewModel) {
                payViewModel = viewModel.payViewModel()
            }
        }
    }

    // MARK: - Bar and button

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if let previous = viewModel.previousStep {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.back()
                } label: {
                    HStack(spacing: 2) {
                        DSIcon(.chevronLeft, role: .body)
                        Text(previous.title)
                    }
                }
                .accessibilityLabel(Text("Back to \(previous.title)"))
                .disabled(viewModel.sendState == .sending)
            }
        }
        if !viewModel.isDone {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") {
                    if viewModel.hasUnsavedChanges {
                        isConfirmingCancel = true
                    } else {
                        onClose(false)
                    }
                }
                .disabled(viewModel.sendState == .sending)
            }
        }
    }

    private var buttonTitle: LocalizedStringKey {
        guard viewModel.step == .waiver else { return "Continue" }
        if case .failed = viewModel.sendState {
            return "Try again"
        }
        return "Sign and continue"
    }

    @ViewBuilder private var bottomButton: some View {
        // The last-slot step brings its own buttons.
        if viewModel.sendState != .lastSlotTaken {
            VStack(spacing: 12) {
                if !isOnline, !viewModel.isDone {
                    EntryStatusLine(
                        systemImage: "wifi.slash",
                        text: String(
                            localized: "You're offline. Connect to the internet to send your registration."
                        )
                    )
                }
                if viewModel.isDone {
                    Button("Done") { onClose(true) }
                        .buttonStyle(.ds(.primary))
                } else {
                    Button(buttonTitle) {
                        Task { await viewModel.continueTapped() }
                    }
                    .buttonStyle(.ds(.primary, isLoading: viewModel.sendState == .sending))
                }
            }
            .screenMargins()
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }
}

extension PayTripViewModel: Identifiable, Hashable {
    nonisolated static func == (lhs: PayTripViewModel, rhs: PayTripViewModel) -> Bool {
        lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

// MARK: - Previews

@MainActor
private func previewRegistration(_ id: String) async -> RegistrationViewModel? {
    let api = EventsAPI(client: StubHTTPClient(SampleStub.handle))
    guard let detail = try? await api.event(id: id) else { return nil }
    return RegistrationViewModel(detail: detail, api: api, imageLoader: URLSessionImageLoader())
}

private struct RegistrationPreview: View {
    let id: String
    @State private var viewModel: RegistrationViewModel?

    var body: some View {
        Color.clear.sheet(isPresented: .constant(true)) {
            if let viewModel {
                RegistrationView(viewModel: viewModel) { _ in }
            }
        }
        .task { viewModel = await previewRegistration(id) }
        .theme(.crossdrive)
    }
}

#Preview("Trip") { RegistrationPreview(id: "behia") }
#Preview("Camp") { RegistrationPreview(id: "camp-feb") }
#Preview("Last slot") { RegistrationPreview(id: "behia-lastslot") }
