import DataLayer
import DesignSystem
import SwiftUI

/// Giving to a ministry: a large sheet with its own steps (amount, sign in,
/// pledge), then a thank-you. Nothing is lost on Cancel: the pledge is saved
/// on the server as soon as it shows.
struct GiveView: View {
    @State private var viewModel: GiveViewModel
    private let onClose: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline

    init(viewModel: GiveViewModel, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        Group {
            // A guest's sign-in is the app's own sign-in screen, with its own steps.
            if viewModel.step == .signIn, let signIn = viewModel.signIn {
                EntryView(viewModel: signIn, onCancel: viewModel.backToAmount)
                    .transition(.opacity)
            } else {
                sheet
            }
        }
        .animation(DesignSystem.Motion.enter, value: viewModel.step)
        .dsToast($viewModel.toast)
        .interactiveDismissDisabled(viewModel.isSending)
        // The reference and the payment numbers stay out of the app switcher.
        .privacyCover()
        .onAppear { viewModel.isOnline = isOnline }
        .onChange(of: isOnline) { _, isOnline in viewModel.isOnline = isOnline }
    }

    private var sheet: some View {
        NavigationStack {
            content
                .background(theme.background)
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
                .navigationTitle(viewModel.ministry.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(viewModel.step == .thanks ? .hidden : .visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel", action: onClose).disabled(viewModel.isSending)
                    }
                }
                .animation(DesignSystem.Motion.enter, value: viewModel.step)
                .sensoryFeedback(.success, trigger: viewModel.step) { _, step in step == .thanks }
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.step == .thanks {
            GiveThanksStep(viewModel: viewModel)
                .transition(.opacity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.showsSteps {
                        CDStepRow(titles: viewModel.stepTitles, current: viewModel.stepIndex)
                    }
                    Group {
                        if viewModel.step == .amount {
                            GiveAmountStep(viewModel: viewModel)
                        } else {
                            GivePledgeStep(viewModel: viewModel)
                        }
                    }
                    .id(viewModel.step)
                    .transition(.opacity)
                }
                .screenMargins()
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Bottom bar

    private var bankLinkTitle: LocalizedStringKey {
        viewModel.paysByBank ? "Pay by GCash instead" : "Pay by bank transfer instead"
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            switch viewModel.step {
            case .amount:
                Button("Continue") { Task { await viewModel.continueTapped() } }
                    .buttonStyle(.ds(.primary, isLoading: viewModel.isSending))
            case .pledge:
                Button("I've sent it") { Task { await viewModel.markSent() } }
                    .buttonStyle(.ds(.primary, isLoading: viewModel.isSending))
                if viewModel.pledge?.bank != nil {
                    Button(bankLinkTitle) { viewModel.paysByBank.toggle() }
                        .registrationLink()
                }
            case .thanks:
                Button("Done", action: onClose)
                    .buttonStyle(.ds(.primary))
            case .signIn:
                EmptyView()
            }
        }
        .screenMargins()
        .padding(.vertical, 12)
        .background(viewModel
            .step == .thanks ? AnyShapeStyle(theme.background) : AnyShapeStyle(.regularMaterial))
    }
}

// MARK: - Previews

@MainActor
private func previewViewModel(kind: Ministry.Kind = .school) -> GiveViewModel {
    let ministries = try? JSONDecoder().decode(
        [MinistryDTO].self,
        from: Data(SampleStub.ministriesJSON.utf8)
    )
    let ministry = MinistryMapper().models(from: ministries ?? [])
        .first { $0.kind == kind }
        ?? Ministry(id: "m", name: "Ministry", summary: "", kind: kind)
    return GiveViewModel(
        ministry: ministry,
        api: MinistriesAPI(client: StubHTTPClient(SampleStub.handle)),
        userName: { "Joy Santos" }
    )
}

#Preview("School fund") {
    GiveView(viewModel: previewViewModel(), onClose: {}).theme(.crossdrive)
}

#Preview("Bible study") {
    GiveView(viewModel: previewViewModel(kind: .bibleStudy), onClose: {}).theme(.crossdrive)
}
