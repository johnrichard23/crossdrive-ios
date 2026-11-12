/// The cross-cutting services, grouped so the container and its tests carry
/// one value instead of six. Each has a default that does nothing or only
/// talks to the system, so the app runs with none of them configured.
struct PlatformServices: Sendable {
    var push: any PushRegistrar
    var connectivity: any Connectivity
    var flags: any FeatureFlags
    var analytics: any Analytics
    var crashReporter: any CrashReporter
    var startupTasks: [StartupTask]

    /// What the running app uses. Vendor hooks (analytics, crash reporting) drop everything.
    static var system: PlatformServices {
        PlatformServices(
            push: SystemPushRegistrar(),
            connectivity: NetworkConnectivity(),
            flags: LocalFeatureFlags(),
            analytics: NoAnalytics(),
            crashReporter: NoCrashReporter(),
            startupTasks: []
        )
    }

    /// For previews and tests: nothing touches the system.
    static var preview: PlatformServices {
        PlatformServices(
            push: FakePushRegistrar(),
            connectivity: FakeConnectivity(),
            flags: LocalFeatureFlags(defaults: nil),
            analytics: NoAnalytics(),
            crashReporter: NoCrashReporter(),
            startupTasks: []
        )
    }
}
