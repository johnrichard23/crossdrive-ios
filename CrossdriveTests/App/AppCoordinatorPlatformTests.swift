@testable import Crossdrive
import XCTest

/// Links, notification taps, startup tasks, analytics and connectivity on the
/// coordinator. Launch routing is in `LaunchMatrixTests`.
@MainActor
final class AppCoordinatorPlatformTests: XCTestCase {
    private let suiteName = "AppCoordinatorPlatformTests"
    private let dana = AppUser(id: "dana", name: "Dana")
    private let credentials = Credentials(email: "dana@example.com", password: "secret")
    private let scheme = DeepLinkRouter().scheme

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Links

    func testHandleURL_WhenTheAppIsOnMain_ShouldOpenTheItemWithTheListBehindIt() async {
        // Arrange
        let coordinator = await started(AppFeatures())
        coordinator.selectedTab = .more

        // Act
        coordinator.handle(url: link("items/2"))

        // Assert
        XCTAssertEqual(coordinator.selectedTab, .items)
        XCTAssertEqual(coordinator.itemsPath, [.detail("2")])
    }

    func testHandleURL_WhenItArrivesDuringLaunch_ShouldOpenOnceLaunchFinishes() async {
        // Arrange: a cold start from a link.
        let coordinator = makeCoordinator(AppFeatures())

        // Act
        coordinator.handle(url: link("items/2"))
        let duringLaunch = coordinator.itemsPath
        await coordinator.start()

        // Assert
        XCTAssertEqual(duringLaunch, [])
        XCTAssertEqual(coordinator.itemsPath, [.detail("2")])
    }

    func testHandleURL_WhenOnboardingIsShowing_ShouldWaitUntilItIsFinished() async {
        // Arrange
        let coordinator = await started(AppFeatures(onboarding: true))
        coordinator.handle(url: link("items/2"))
        let duringOnboarding = coordinator.itemsPath

        // Act
        coordinator.finishOnboarding()

        // Assert
        XCTAssertEqual(duringOnboarding, [])
        XCTAssertEqual(coordinator.itemsPath, [.detail("2")])
    }

    func testHandleURL_WhenSignInIsRequiredAndNobodyIsSignedIn_ShouldWaitUntilTheyHaveSignedIn(
    ) async throws {
        // Arrange
        let coordinator = await started(
            AppFeatures(authentication: .required),
            session: FakeAuthSession(signInResult: .success(dana))
        )
        coordinator.handle(url: link("items/2"))
        let beforeSignIn = coordinator.itemsPath

        // Act
        try await coordinator.signIn(credentials)

        // Assert
        XCTAssertEqual(beforeSignIn, [])
        XCTAssertEqual(coordinator.itemsPath, [.detail("2")])
    }

    func testHandleURL_WhenItIsNotOneOfOurs_ShouldChangeNothing() async {
        // Arrange
        let analytics = RecordingAnalytics()
        let coordinator = await started(AppFeatures(), services: .testing(analytics: analytics))

        // Act
        coordinator.handle(url: URL(fileURLWithPath: "/elsewhere"))
        coordinator.handle(url: link("settings/1"))

        // Assert
        XCTAssertEqual(coordinator.itemsPath, [])
        XCTAssertFalse(analytics.events.contains(.deepLinkOpened))
    }

    func testHandleURL_WhenASecondLinkArrivesBeforeTheFirstOpened_ShouldOpenOnlyTheLastOne() async {
        // Arrange
        let coordinator = makeCoordinator(AppFeatures())
        coordinator.handle(url: link("items/1"))
        coordinator.handle(url: link("items/2"))

        // Act
        await coordinator.start()

        // Assert
        XCTAssertEqual(coordinator.itemsPath, [.detail("2")])
    }

    func testSignOut_WhenALinkIsOpen_ShouldLeaveTheTabsAtTheirRoots() async {
        // Arrange
        let coordinator = await started(
            AppFeatures(authentication: .optional),
            session: FakeAuthSession(state: .signedIn(dana))
        )
        coordinator.handle(url: link("items/2"))
        coordinator.handlePushTap(link: "\(scheme)://items/3")

        // Act
        await coordinator.signOut()

        // Assert
        XCTAssertEqual(coordinator.itemsPath, [])
        XCTAssertEqual(coordinator.selectedTab, .items)
        XCTAssertNil(coordinator.presentedLink)
    }

    func testSession_WhenItEndsWhileALinkIsWaiting_ShouldNotOpenItForTheNextPerson() async throws {
        // Arrange: signed in, still in onboarding, and a link arrives and waits.
        let session = FakeAuthSession(state: .signedIn(dana), signInResult: .success(dana))
        let coordinator = await started(
            AppFeatures(authentication: .required, onboarding: true),
            session: session
        )
        XCTAssertEqual(coordinator.flow, .onboarding)
        coordinator.handle(url: link("items/2"))

        // Act: the session ends by itself, and someone signs in again.
        await session.send(.signedOut)
        await waitUntil { coordinator.flow == .auth }
        try await coordinator.signIn(credentials)
        coordinator.finishOnboarding()

        // Assert
        XCTAssertEqual(coordinator.flow, .main)
        XCTAssertEqual(coordinator.itemsPath, [])
    }

    // MARK: - Notification taps

    func testHandlePushTap_WhenTheAppIsOnMain_ShouldPresentTheItemInASheetAndKeepThePlace() async {
        // Arrange
        let coordinator = await started(AppFeatures())
        coordinator.handle(url: link("items/1"))

        // Act
        coordinator.handlePushTap(link: "\(scheme)://items/2")

        // Assert
        XCTAssertEqual(coordinator.presentedLink?.link, .item("2"))
        XCTAssertEqual(coordinator.itemsPath, [.detail("1")])
    }

    func testHandlePushTap_WhenItStartedTheApp_ShouldPresentAfterLaunch() async {
        // Arrange
        let coordinator = makeCoordinator(AppFeatures())
        coordinator.handlePushTap(link: "\(scheme)://items/2")
        let duringLaunch = coordinator.presentedLink

        // Act
        await coordinator.start()

        // Assert
        XCTAssertNil(duringLaunch)
        XCTAssertEqual(coordinator.presentedLink?.link, .item("2"))
    }

    func testHandlePushTap_WhenThePayloadLinkIsNotOneOfOurs_ShouldDoNothing() async {
        // Arrange
        let analytics = RecordingAnalytics()
        let coordinator = await started(AppFeatures(), services: .testing(analytics: analytics))

        // Act
        coordinator.handlePushTap(link: "https://evil.example.org/items/2")
        coordinator.handlePushTap(link: "garbage")

        // Assert
        XCTAssertNil(coordinator.presentedLink)
        XCTAssertFalse(analytics.events.contains(.pushTapped))
    }

    // MARK: - Analytics and crash reporting

    func testAnalytics_WhenTheUserGoesThroughTheApp_ShouldReportEachStepOnce() async throws {
        // Arrange
        let analytics = RecordingAnalytics()
        let coordinator = await started(
            AppFeatures(authentication: .optional, onboarding: true),
            session: FakeAuthSession(signInResult: .success(dana)),
            services: .testing(analytics: analytics)
        )

        // Act
        coordinator.finishOnboarding()
        coordinator.handle(url: link("items/1"))
        coordinator.handlePushTap(link: "\(scheme)://items/2")
        try await coordinator.signIn(credentials)
        await coordinator.signOut()

        // Assert
        XCTAssertEqual(
            analytics.events,
            [.appOpened, .onboardingFinished, .deepLinkOpened, .pushTapped, .signedIn, .signedOut]
        )
    }

    func testCrashReporter_WhenTheSessionChanges_ShouldKnowTheUserIDOnly() async throws {
        // Arrange
        let reporter = RecordingCrashReporter()
        let coordinator = await started(
            AppFeatures(authentication: .optional),
            session: FakeAuthSession(signInResult: .success(dana)),
            services: .testing(crashReporter: reporter)
        )

        // Act
        try await coordinator.signIn(credentials)
        await coordinator.signOut()

        // Assert
        XCTAssertEqual(reporter.userIDs.values, [nil, "dana", nil])
    }

    // MARK: - Startup tasks

    func testStartupTasks_WhenTheAppLaunches_ShouldRunLaunchTasksOnly() async {
        // Arrange
        let ran = Recorder<String>()
        let coordinator = makeCoordinator(
            AppFeatures(),
            services: .testing(startupTasks: tasks(recording: ran))
        )

        // Act
        await coordinator.start()
        await waitUntil { ran.values.contains("launch") }

        // Assert
        XCTAssertEqual(ran.values, ["launch"])
    }

    func testStartupTasks_WhenASessionIsRestored_ShouldAlsoRunSignedInTasks() async {
        // Arrange
        let ran = Recorder<String>()
        let coordinator = makeCoordinator(
            AppFeatures(),
            session: FakeAuthSession(state: .signedIn(dana)),
            services: .testing(startupTasks: tasks(recording: ran))
        )

        // Act
        await coordinator.start()
        await waitUntil { ran.values.count == 2 }

        // Assert
        XCTAssertEqual(Set(ran.values), ["launch", "signedIn"])
    }

    func testStartupTasks_WhenTheUserSignsIn_ShouldRunSignedInTasks() async throws {
        // Arrange
        let ran = Recorder<String>()
        let coordinator = makeCoordinator(
            AppFeatures(),
            session: FakeAuthSession(signInResult: .success(dana)),
            services: .testing(startupTasks: tasks(recording: ran))
        )
        await coordinator.start()
        await waitUntil { ran.values.contains("launch") }

        // Act
        try await coordinator.signIn(credentials)
        await waitUntil { ran.values.contains("signedIn") }

        // Assert
        XCTAssertEqual(ran.values, ["launch", "signedIn"])
    }

    // MARK: - Connectivity

    func testIsOnline_WhenTheConnectionDropsAndReturns_ShouldFollowIt() async {
        // Arrange
        let connectivity = FakeConnectivity()
        let coordinator = await started(
            AppFeatures(),
            services: .testing(connectivity: connectivity)
        )
        XCTAssertTrue(coordinator.isOnline)

        // Act
        await connectivity.send(false)
        await waitUntil { !coordinator.isOnline }
        let whileOffline = coordinator.isOnline
        await connectivity.send(true)
        await waitUntil { coordinator.isOnline }

        // Assert
        XCTAssertFalse(whileOffline)
        XCTAssertTrue(coordinator.isOnline)
    }

    // MARK: - Helpers

    private func link(_ path: String) -> URL {
        URL(string: "\(scheme)://\(path)") ?? URL(fileURLWithPath: "/invalid")
    }

    private func tasks(recording ran: Recorder<String>) -> [StartupTask] {
        [
            StartupTask(name: "launch", trigger: .launch) { ran.add("launch") },
            StartupTask(name: "signedIn", trigger: .signedIn) { ran.add("signedIn") },
        ]
    }

    private func makeCoordinator(
        _ features: AppFeatures,
        session: (any AuthSession)? = nil,
        services: PlatformServices = .preview
    ) -> AppCoordinator {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let container = DependencyContainer.preview(
            features: features,
            session: session ?? FakeAuthSession(),
            onboarding: OnboardingStore(defaults: defaults),
            services: services
        )
        return AppCoordinator(container: container)
    }

    private func started(
        _ features: AppFeatures,
        session: (any AuthSession)? = nil,
        services: PlatformServices = .preview
    ) async -> AppCoordinator {
        let coordinator = makeCoordinator(features, session: session, services: services)
        await coordinator.start()
        return coordinator
    }

    /// Lets other main-actor work run until `condition` holds. No sleeping.
    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0 ..< 1000 {
            if condition() {
                return
            }
            await Task.yield()
        }
    }
}
