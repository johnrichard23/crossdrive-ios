import SwiftUI

/// One page of onboarding. A project replaces `sample` with its own pages.
struct OnboardingPage: Identifiable, Sendable {
    let id: String
    let systemImage: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource
}

extension OnboardingPage {
    /// Placeholder pages. Replace the text and symbols, or the whole list.
    static let sample = [
        OnboardingPage(
            id: "welcome",
            systemImage: "sparkles",
            title: "Welcome",
            message: "Everything you need, in one place."
        ),
        OnboardingPage(
            id: "updates",
            systemImage: "bell",
            title: "Stay in the loop",
            message: "Get a heads-up when something changes."
        ),
        OnboardingPage(
            id: "control",
            systemImage: "slider.horizontal.3",
            title: "You're in control",
            message: "Change your settings any time from the More tab."
        ),
    ]
}
