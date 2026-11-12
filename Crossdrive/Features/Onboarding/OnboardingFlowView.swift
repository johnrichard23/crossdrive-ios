import DesignSystem
import SwiftUI

/// Swipeable pages with Skip, a step indicator and one primary button.
struct OnboardingFlowView: View {
    @State private var viewModel: OnboardingViewModel

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: OnboardingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: theme.spacing.groupGap) {
            skipRow

            TabView(selection: $viewModel.index) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    pageView(page).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            DSStepIndicator(step: viewModel.index + 1, of: viewModel.pages.count)
                .screenMargins()
        }
        .padding(.vertical, theme.spacing.groupGap)
        .background(theme.background)
        .dsBottomBar {
            Button(action: advance) {
                Text(primaryTitle)
            }
            .buttonStyle(.ds(.primary))
        }
        .dsHaptic(.selection, trigger: viewModel.index)
        .task { viewModel.start() }
    }

    /// Paging slides sideways; under Reduce Motion the page just changes.
    private func advance() {
        withAnimation(reduceMotion ? nil : DesignSystem.Motion.enter) {
            viewModel.advance()
        }
    }

    private var primaryTitle: LocalizedStringKey {
        viewModel.isLastPage ? "Get started" : "Continue"
    }

    /// Always laid out, so the pages don't jump when it disappears on the last one.
    private var skipRow: some View {
        HStack {
            Spacer()
            Button("Skip") { viewModel.finish() }
                .buttonStyle(.ds(.plain, size: .regular, expandsWidth: false))
                .opacity(viewModel.isLastPage ? 0 : 1)
                .disabled(viewModel.isLastPage)
                .accessibilityHidden(viewModel.isLastPage)
        }
        .screenMargins()
        .animation(DesignSystem.Motion.enter, value: viewModel.isLastPage)
    }

    /// Centred when it fits; scrolls instead of cutting text off when it
    /// doesn't (the largest text sizes).
    private func pageView(_ page: OnboardingPage) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: theme.spacing.groupGap) {
                    DSIcon(.system(page.systemImage), role: .largeTitle)
                        .foregroundStyle(theme.accent)
                        .padding(theme.spacing.xl)
                        .background(theme.surface, in: Circle())

                    VStack(spacing: theme.spacing.xs) {
                        Text(page.title)
                            .textRole(.title1, emphasized: true)
                        Text(page.message)
                            .textRole(.body)
                            .foregroundStyle(theme.labelSecondary)
                    }
                    .multilineTextAlignment(.center)
                }
                .screenMargins()
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingFlowView(viewModel: OnboardingViewModel(pages: OnboardingPage.sample) {})
        .theme(.system)
}
