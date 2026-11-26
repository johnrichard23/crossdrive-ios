import DesignSystem
import SwiftUI

/// Shows whichever flow the coordinator says, cross-fading between them, with
/// the login gate and notification sheets over it, and a banner when the
/// device is offline.
struct RootView: View {
    @Bindable var coordinator: AppCoordinator

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // A VStack, not a top safe-area inset: tab screens with their own
        // header (Home, Events, Ministries) drew under an inset banner.
        VStack(spacing: 0) {
            offlineBanner
            flowContent
        }
        .background(theme.background)
        .animation(DesignSystem.Motion.enter, value: coordinator.flow)
        // The banner pushes the screen down: movement, so none under Reduce Motion.
        .animation(reduceMotion ? nil : DesignSystem.Motion.enter, value: coordinator.isOnline)
        .environment(\.accountGate, AccountGate { trip, action in
            coordinator.requireAccount(for: trip, action)
        })
        .environment(\.isOnline, coordinator.isOnline)
        .environment(\.featureFlags, coordinator.container.services.flags)
        .sheet(item: $coordinator.loginGate, onDismiss: coordinator.loginGateDidDismiss) { gate in
            EntryView(viewModel: gate.viewModel) { coordinator.loginGate = nil }
        }
        .sheet(item: $coordinator.presentedLink) { presented in
            switch presented.link {
            case let .item(id): ItemSheetView(itemID: id, container: coordinator.container)
            case let .trip(id): MyTripSheet(tripID: id, container: coordinator.container)
            }
        }
        .onOpenURL { coordinator.handle(url: $0) }
        .task { await coordinator.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await coordinator.sceneDidBecomeActive() }
            }
        }
    }
}

private extension RootView {
    var flowContent: some View {
        ZStack {
            switch coordinator.flow {
            case .launching:
                SplashView().transition(.opacity)
            case .onboarding:
                OnboardingFlowView(
                    viewModel: OnboardingViewModel(
                        pages: OnboardingPage.sample,
                        onFinish: coordinator.finishOnboarding
                    )
                )
                .transition(.opacity)
            case .auth:
                SignInView(viewModel: SignInViewModel(signIn: coordinator.signIn))
                    .transition(.opacity)
            case .main:
                MainTabView(coordinator: coordinator)
                    .id(coordinator.mainResetToken)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder var offlineBanner: some View {
        if coordinator.flow == .main, !coordinator.isOnline {
            DSBanner(
                String(localized: "You're offline. What you see may be out of date."),
                kind: .warning
            )
            .screenMargins()
            .transition(.opacity)
        }
    }
}

#Preview("Launching") {
    RootView(coordinator: AppCoordinator(container: .preview()))
        .theme(.system)
}
