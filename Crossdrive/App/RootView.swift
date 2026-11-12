import DesignSystem
import SwiftUI

/// Shows whichever flow the coordinator says, cross-fading between them, with
/// the login gate and notification sheets over it, and a banner when the
/// device is offline.
struct RootView: View {
    @Bindable var coordinator: AppCoordinator

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
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
        .safeAreaInset(edge: .top) { offlineBanner }
        .animation(DesignSystem.Motion.enter, value: coordinator.flow)
        // The banner pushes the screen down: movement, so none under Reduce Motion.
        .animation(reduceMotion ? nil : DesignSystem.Motion.enter, value: coordinator.isOnline)
        .environment(\.accountGate, AccountGate { coordinator.requireAccount($0) })
        .environment(\.isOnline, coordinator.isOnline)
        .environment(\.featureFlags, coordinator.container.services.flags)
        .sheet(item: $coordinator.loginGate, onDismiss: coordinator.loginGateDidDismiss) { _ in
            NavigationStack {
                SignInView(viewModel: SignInViewModel(signIn: coordinator.signIn))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { coordinator.loginGate = nil }
                        }
                    }
            }
        }
        .sheet(item: $coordinator.presentedLink) { presented in
            switch presented.link {
            case let .item(id): ItemSheetView(itemID: id, container: coordinator.container)
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
