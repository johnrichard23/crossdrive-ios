import Foundation
import Observation

/// Owns which flow is on screen, who is signed in, the login gate, where a
/// link or a notification sends the user, and whether the device is online.
/// `RootView` switches on `flow`.
///
/// One-way doors (launch finished, onboarding finished, sign-in finished in a
/// required-account app) change the flow instead of pushing a screen, so
/// there is nothing to go back to.
@Observable @MainActor
final class AppCoordinator {
    /// A request to sign in, shown as a sheet over the current screen.
    struct LoginGate: Identifiable {
        let id = UUID()
    }

    /// Something a notification tap opens, shown as a sheet over the current screen.
    struct PresentedLink: Identifiable {
        let id = UUID()
        let link: DeepLink
    }

    private enum Presentation {
        /// A link: build the whole stack in its tab.
        case navigate
        /// A notification tap: a sheet, so the user keeps their place.
        case sheet
    }

    private struct PendingLink {
        let link: DeepLink
        let presentation: Presentation
    }

    private(set) var flow: AppFlow = .launching
    private(set) var session: SessionState = .signedOut
    /// Changes when the main tabs must be rebuilt from scratch (sign-out), so
    /// nothing of the previous user is left on screen.
    private(set) var mainResetToken = UUID()
    private(set) var isOnline = true
    var loginGate: LoginGate?
    var presentedLink: PresentedLink?
    var selectedTab = MainTab.items
    var itemsPath: [SampleRoute] = []

    let container: DependencyContainer

    private let router: DeepLinkRouter
    private var pendingAction: (@MainActor () -> Void)?
    private var pendingLink: PendingLink?
    private var sessionObservation: Task<Void, Never>?
    private var connectivityObservation: Task<Void, Never>?

    private var services: PlatformServices {
        container.services
    }

    init(container: DependencyContainer, router: DeepLinkRouter = DeepLinkRouter()) {
        self.container = container
        self.router = router
    }

    /// Restores the session, then leaves the splash for the right flow.
    /// Safe to call again: only the first call does anything.
    func start() async {
        guard flow == .launching else { return }
        session = await container.session.restore()
        services.crashReporter.setUserID(session.user?.id)
        observeSession()
        observeConnectivity()
        services.analytics.track(.appOpened)
        runStartupTasks(.launch)
        if session.user != nil {
            runStartupTasks(.signedIn)
        }
        route()
    }

    /// Onboarding is over: remember it and move on.
    func finishOnboarding() {
        container.onboarding.markDone(for: session)
        services.analytics.track(.onboardingFinished)
        route()
    }

    // MARK: - Links and notifications

    /// A URL opened the app (or arrived while it was open).
    func handle(url: URL) {
        guard let link = router.parse(url) else {
            AppLog.navigation.info("Ignored a link that isn't one of ours")
            return
        }
        services.analytics.track(.deepLinkOpened)
        receive(link, as: .navigate)
    }

    /// The user tapped a notification whose payload carried `link`.
    func handlePushTap(link text: String) {
        guard let link = router.parse(text) else {
            AppLog.navigation.info("Ignored a notification link that isn't one of ours")
            return
        }
        services.analytics.track(.pushTapped)
        receive(link, as: .sheet)
    }

    // MARK: - Accounts

    /// Runs `action` now if the user may do it, or after they sign in.
    ///
    /// In an app with optional accounts, a guest is shown the login gate and
    /// the action runs once they have signed in. Cancelling the gate drops the
    /// action; it is never retried on its own. Anywhere else there is nothing
    /// to ask, so the action runs at once.
    func requireAccount(_ action: @escaping @MainActor () -> Void) {
        guard container.features.authentication == .optional, session == .signedOut else {
            action()
            return
        }
        pendingAction = action
        if loginGate == nil {
            loginGate = LoginGate()
        }
    }

    /// The sheet went away without a sign-in (cancel button or swipe down).
    func loginGateDidDismiss() {
        pendingAction = nil
    }

    func signIn(_ credentials: Credentials) async throws {
        let user = try await container.session.signIn(credentials)
        apply(.signedIn(user))
    }

    func signOut() async {
        await container.signOut()
        apply(.signedOut)
    }

    /// The app came back to the foreground.
    func sceneDidBecomeActive() async {
        await container.refreshSessionIfNeeded()
    }

    // MARK: - Private

    private func observeSession() {
        let updates = container.session.stateUpdates
        sessionObservation = Task { [weak self] in
            for await state in updates {
                self?.apply(state)
            }
        }
    }

    private func observeConnectivity() {
        let updates = services.connectivity.updates
        connectivityObservation = Task { [weak self] in
            for await isOnline in updates {
                self?.isOnline = isOnline
            }
        }
    }

    /// Takes a new session state, from our own sign-in or sign-out or from the
    /// session changing by itself. Safe to apply twice.
    private func apply(_ state: SessionState) {
        guard state != session else { return }
        session = state
        services.crashReporter.setUserID(state.user?.id)

        switch state {
        case .signedIn:
            services.analytics.track(.signedIn)
            let action = pendingAction
            pendingAction = nil
            loginGate = nil
            runStartupTasks(.signedIn)
            route()
            action?()
        case .signedOut:
            services.analytics.track(.signedOut)
            // Nothing of the last user's place in the app carries over.
            pendingAction = nil
            pendingLink = nil
            loginGate = nil
            presentedLink = nil
            selectedTab = .items
            itemsPath = []
            route()
            mainResetToken = UUID()
        }
    }

    private func route() {
        let next = LaunchRouter.flow(
            features: container.features,
            session: session,
            onboardingDone: container.onboarding.isDone(for: session)
        )
        flow = next
        AppLog.navigation.info("Flow: \(String(describing: next), privacy: .public)")
        openPendingLinkIfPossible()
    }

    private func receive(_ link: DeepLink, as presentation: Presentation) {
        pendingLink = PendingLink(link: link, presentation: presentation)
        openPendingLinkIfPossible()
    }

    /// A link can arrive before there is anywhere to put it (during launch,
    /// onboarding or sign-in). It waits, and opens once the main screen is up.
    private func openPendingLinkIfPossible() {
        guard flow == .main, let pending = pendingLink else { return }
        pendingLink = nil

        switch pending.presentation {
        case .navigate:
            selectedTab = .items
            switch pending.link {
            case let .item(id): itemsPath = [.detail(id)]
            }
        case .sheet:
            presentedLink = PresentedLink(link: pending.link)
        }
    }

    private func runStartupTasks(_ trigger: StartupTask.Trigger) {
        let tasks = services.startupTasks.filter { $0.trigger == trigger }
        guard !tasks.isEmpty else { return }
        Task {
            for task in tasks {
                await task.run()
            }
        }
    }
}
