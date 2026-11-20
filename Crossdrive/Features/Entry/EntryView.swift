import DesignSystem
import SwiftUI

/// The sign-in sheet: a stack of steps over the email step. Cancel is on every
/// step; back returns one step.
struct EntryView: View {
    @State private var viewModel: EntryViewModel
    private let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale

    init(viewModel: EntryViewModel, onCancel: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            EntryEmailStep(viewModel: viewModel, onCancel: onCancel)
                .navigationDestination(for: EntryViewModel.Step.self) { step in
                    switch step {
                    case .password: EntryPasswordStep(viewModel: viewModel, onCancel: onCancel)
                    case .create: EntryCreateStep(viewModel: viewModel, onCancel: onCancel)
                    case .checkEmail: EntryCheckEmailStep(viewModel: viewModel, onCancel: onCancel)
                    case .reset: EntryResetStep(viewModel: viewModel, onCancel: onCancel)
                    }
                }
        }
        .background(theme.background)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(22)
        .interactiveDismissDisabled(viewModel.isSubmitting)
        .task { await viewModel.loadMedia(scale: displayScale) }
        .animation(DesignSystem.Motion.enter, value: viewModel.photos.count)
    }
}

/// The frame every step shares: scrolling content, Cancel on the right, an
/// optional back button that names the step before, and an optional pinned bar.
struct EntryScaffold<Content: View, Bar: View>: View {
    var back: LocalizedStringKey?
    /// The field being typed in; the page scrolls it above the keyboard and the pinned button.
    var focusedID: String?
    let onCancel: () -> Void
    @ViewBuilder var content: Content
    @ViewBuilder var bar: Bar

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if Bar.self == EmptyView.self {
            page
        } else {
            page.dsBottomBar { bar }
        }
    }

    private var page: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .task(id: focusedID) {
                guard let focusedID else { return }
                // Let the keyboard finish rising, then bring the field into the space left.
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(DesignSystem.Motion.enter) {
                    proxy.scrollTo(focusedID, anchor: .center)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            backItem
            cancelItem
        }
    }

    /// Plain text with a chevron, as the sheet draws it; iOS 26 would show only a glass circle.
    @ToolbarContentBuilder private var backItem: some ToolbarContent {
        if let back {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarLeading) { backButton(back) }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarLeading) { backButton(back) }
            }
        }
    }

    private func backButton(_ title: LocalizedStringKey) -> some View {
        Button { dismiss() } label: {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left").fontWeight(.semibold)
                Text(title)
            }
        }
        .accessibilityLabel(Text("Back"))
    }

    /// Plain text on the right, as the sheet draws it; iOS 26 would put it in a glass capsule.
    @ToolbarContentBuilder private var cancelItem: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { Button("Cancel", action: onCancel) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { Button("Cancel", action: onCancel) }
        }
    }
}
