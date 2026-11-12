@testable import Crossdrive

/// Remembers every analytics event, so a test can read what was reported.
struct RecordingAnalytics: Analytics {
    let recorder = Recorder<AnalyticsEvent>()

    var events: [AnalyticsEvent] {
        recorder.values
    }

    func track(_ event: AnalyticsEvent) {
        recorder.add(event)
    }
}

/// Remembers recorded errors and user ids.
struct RecordingCrashReporter: CrashReporter {
    let errors = Recorder<String>()
    let userIDs = Recorder<String?>()

    func record(_: any Error, context: String) {
        errors.add(context)
    }

    func setUserID(_ id: String?) {
        userIDs.add(id)
    }
}

/// Lets the test decide what to do when `unregister()` is called.
struct ProbingPushRegistrar: PushRegistrar {
    let onUnregister: @Sendable () async -> Void

    func authorization() async -> PushAuthorization {
        .authorized
    }

    func requestAuthorization() async -> PushAuthorization {
        .authorized
    }

    func unregister() async {
        await onUnregister()
    }
}

/// A notification prompt that stays open until the test answers it.
struct GatedPushRegistrar: PushRegistrar {
    let started: Gate
    let release: Gate
    let prompts: Counter

    func authorization() async -> PushAuthorization {
        .notDetermined
    }

    func requestAuthorization() async -> PushAuthorization {
        _ = prompts.next()
        await started.open()
        await release.wait()
        return .authorized
    }

    func unregister() async {}
}

extension PlatformServices {
    /// The preview services, with the given pieces swapped in.
    static func testing(
        push: (any PushRegistrar)? = nil,
        connectivity: (any Connectivity)? = nil,
        analytics: (any Analytics)? = nil,
        crashReporter: (any CrashReporter)? = nil,
        startupTasks: [StartupTask] = []
    ) -> PlatformServices {
        var services = PlatformServices.preview
        if let push {
            services.push = push
        }
        if let connectivity {
            services.connectivity = connectivity
        }
        if let analytics {
            services.analytics = analytics
        }
        if let crashReporter {
            services.crashReporter = crashReporter
        }
        services.startupTasks = startupTasks
        return services
    }
}
