import DataLayer
import Foundation
import Observation

/// Joining a trip or a camp, one step at a time. Opened from Trip detail once
/// the person is signed in; the sheet owns it while it is up.
@Observable @MainActor
final class RegistrationViewModel {
    enum SendState: Equatable {
        case idle
        case sending
        /// Nothing was made. The words say why; everything typed is kept.
        case failed(String)
        /// Someone took the last slot while this person was filling in.
        case lastSlotTaken
    }

    let detail: EventDetail
    let steps: [RegistrationStep]
    var form = RegistrationForm()
    private(set) var stepIndex = 0
    private(set) var sendState = SendState.idle
    private(set) var result: RegistrationResult?
    /// Steps whose button was tapped, so their errors show. A step shows no
    /// error before the person has tried to leave it.
    private(set) var checkedSteps: Set<RegistrationStep> = []
    /// The trip was full before they started, so this joins its waiting list.
    private(set) var joinsWaitlist: Bool

    private let api: EventsAPI
    private let imageLoader: any ImageLoading
    private let reporter: any CrashReporter
    /// One key per thing being asked for, kept across retries, so a retry after
    /// a timeout never registers twice. Asking for the waiting list is a new ask.
    private var idempotencyKey = UUID().uuidString
    @ObservationIgnored private var pay: PayTripViewModel?

    init(
        detail: EventDetail,
        api: EventsAPI,
        imageLoader: any ImageLoading,
        reporter: any CrashReporter = NoCrashReporter()
    ) {
        self.detail = detail
        self.api = api
        self.imageLoader = imageLoader
        self.reporter = reporter
        steps = RegistrationStep.steps(for: detail.event.kind)
        joinsWaitlist = detail.bar == .full
    }

    var step: RegistrationStep {
        steps[stepIndex]
    }

    /// 1-based, for "Step 2 of 4".
    var stepNumber: Int {
        stepIndex + 1
    }

    var isDone: Bool {
        step == .done
    }

    /// The step to go back to, named on the Back button. `nil` on the first
    /// step and once registered: there is no going back from Done.
    var previousStep: RegistrationStep? {
        guard stepIndex > 0, !isDone else { return nil }
        return steps[stepIndex - 1]
    }

    /// Something typed would be lost by closing the sheet now.
    var hasUnsavedChanges: Bool {
        result == nil && form != RegistrationForm()
    }

    /// The errors to show on the current step.
    var errors: [RegistrationForm.Field: String] {
        guard checkedSteps.contains(step) else { return [:] }
        return form.errors(on: step, kind: detail.event.kind)
    }

    var selectedTeam: EventRole? {
        guard case let .team(id) = form.role else { return nil }
        return detail.roles.first { $0.id == id }
    }

    /// Picks a team. A full team can't be picked.
    func choose(_ role: RegistrationForm.Role) {
        if case let .team(id) = role, detail.roles.first(where: { $0.id == id })?.isFull == true {
            return
        }
        form.role = role
    }

    /// Continue on any step but the waiver; Sign and continue on the waiver.
    func continueTapped() async {
        checkedSteps.insert(step)
        guard form.errors(on: step, kind: detail.event.kind).isEmpty else { return }
        if step == .waiver {
            await send()
        } else {
            stepIndex = min(stepIndex + 1, steps.count - 1)
        }
    }

    func back() {
        guard previousStep != nil, sendState != .sending else { return }
        stepIndex -= 1
        // A failed send or a taken slot belongs to the step they left.
        sendState = .idle
    }

    /// The last slot went while they were filling in: join the waiting list
    /// with everything they already typed.
    func joinWaitingList() async {
        joinsWaitlist = true
        idempotencyKey = UUID().uuidString
        await send()
    }

    /// The Pay screen for this registration. `nil` before it is made.
    /// One per registration, so "I've sent it" is still shown after going back and in again.
    func payViewModel() -> PayTripViewModel? {
        guard let result else { return nil }
        if let pay {
            return pay
        }
        let made = PayTripViewModel(
            detail: detail,
            registration: result,
            api: api,
            imageLoader: imageLoader
        )
        pay = made
        return made
    }

    // MARK: - Sending

    private func send() async {
        // A second tap while the first is out must not register twice.
        guard sendState != .sending, result == nil else { return }
        sendState = .sending
        do {
            let made = try await api.register(
                eventID: detail.event.id,
                form: form,
                kind: detail.event.kind,
                waitlist: joinsWaitlist,
                idempotencyKey: idempotencyKey
            )
            result = made
            sendState = .idle
            stepIndex = steps.count - 1
        } catch let error as NetworkError where error.statusCode == 409 {
            sendState = .lastSlotTaken
        } catch {
            // A reply the app can't read is a bug, not the person's problem: report it.
            if let error = error as? NetworkError, case .decoding = error {
                reporter.record(error, context: "Registering")
            }
            sendState = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: any Error) -> String {
        if error.isOffline {
            return String(localized: """
            We couldn't send your registration. Check your connection and try again. \
            Nothing you typed was lost.
            """)
        }
        return error.userMessage + " " + String(localized: "Nothing you typed was lost.")
    }
}

extension RegistrationViewModel: Identifiable {
    nonisolated var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}
