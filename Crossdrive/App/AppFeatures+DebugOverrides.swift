#if DEBUG
    import Foundation

    extension AppFeatures {
        /// Launch arguments that change the app's shape for one run, in Debug
        /// builds only. In Xcode: Edit Scheme, Run, Arguments. From a shell:
        /// `xcrun simctl launch <device> <bundle id> -feature-auth required -feature-onboarding on`
        ///
        /// - `-feature-auth none | optional | required`
        /// - `-feature-onboarding on | off`
        /// - `-feature-onboarding-placement beforeSignIn | afterSignIn`
        ///
        /// A value that isn't one of these is ignored.
        mutating func applyOverrides(_ defaults: UserDefaults) {
            switch defaults.string(forKey: "feature-auth") {
            case "none": authentication = .none
            case "optional": authentication = .optional
            case "required": authentication = .required
            default: break
            }
            switch defaults.string(forKey: "feature-onboarding") {
            case "on": onboarding = true
            case "off": onboarding = false
            default: break
            }
            switch defaults.string(forKey: "feature-onboarding-placement") {
            case "beforeSignIn": onboardingPlacement = .beforeSignIn
            case "afterSignIn": onboardingPlacement = .afterSignIn
            default: break
            }
        }
    }
#endif
