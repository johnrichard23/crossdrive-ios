import DesignSystem
import Foundation
import SwiftUI
import UserNotifications

@main
struct CrossdriveApp: App {
    private let launch: Result<AppCoordinator, AppEnvironment.ConfigurationError>
    /// The notification centre keeps only a weak reference to its delegate.
    private let notificationHandler: NotificationTapHandler?

    init() {
        do {
            let environment = try AppEnvironment.load()
            let coordinator = AppCoordinator(container: Self.makeContainer(environment))
            launch = .success(coordinator)

            // Set before launch finishes, so tapping a notification that
            // started the app is delivered too.
            let handler = NotificationTapHandler { coordinator.handlePushTap(link: $0) }
            UNUserNotificationCenter.current().delegate = handler
            notificationHandler = handler

            AppLog.app.info("Launching in \(environment.kind.rawValue, privacy: .public)")
        } catch {
            launch = .failure(error)
            notificationHandler = nil
            AppLog.app.fault("Configuration error: \(String(describing: error), privacy: .public)")
        }
    }

    private static func makeContainer(_ environment: AppEnvironment) -> DependencyContainer {
        #if DEBUG
            // Run with no backend: canned replies instead of the network.
            // Everything else (notifications, connectivity, flags) stays real.
            if wantsStubAPI(arguments: CommandLine.arguments, defaults: .standard) {
                return .preview(features: .current, environment: environment, services: .system)
            }
        #endif
        return DependencyContainer(features: .current, environment: environment)
    }

    #if DEBUG
        /// The `-stub-api` launch argument (what the Xcode scheme passes), or,
        /// for a start that can't take arguments (a link, a notification),
        /// `defaults write <bundle id> stub-api -bool YES`.
        nonisolated static func wantsStubAPI(arguments: [String], defaults: UserDefaults) -> Bool {
            arguments.contains("-stub-api") || defaults.bool(forKey: "stub-api")
        }
    #endif

    var body: some Scene {
        WindowGroup {
            Group {
                switch launch {
                case let .success(coordinator):
                    RootView(coordinator: coordinator)
                case let .failure(error):
                    ConfigurationErrorView(error: error)
                }
            }
            // Set once, here.
            .theme(.crossdrive)
        }
    }
}
