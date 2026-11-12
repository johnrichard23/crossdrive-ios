import Observation

/// Which page is showing, and when onboarding is over. It never decides what
/// happens next: `onFinish` hands that to the coordinator.
@Observable @MainActor
final class OnboardingViewModel {
    let pages: [OnboardingPage]
    /// The page on screen. Bound to the pager, so swiping changes it too.
    var index = 0
    private(set) var isFinished = false

    private let onFinish: @MainActor () -> Void

    init(pages: [OnboardingPage], onFinish: @escaping @MainActor () -> Void) {
        self.pages = pages
        self.onFinish = onFinish
    }

    var isLastPage: Bool {
        index >= pages.count - 1
    }

    /// With no pages there is nothing to show: finish at once instead of
    /// leaving the user on an empty screen.
    func start() {
        if pages.isEmpty {
            finish()
        }
    }

    /// Continue to the next page, or finish from the last one.
    func advance() {
        if isLastPage {
            finish()
        } else {
            index += 1
        }
    }

    /// Skip and Get started both end here. Safe to call twice (a double tap).
    func finish() {
        guard !isFinished else { return }
        isFinished = true
        onFinish()
    }
}
