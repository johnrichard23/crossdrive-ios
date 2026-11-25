@testable import Crossdrive
import DataLayer
import SwiftUI
import XCTest

@MainActor
final class RegistrationViewModelTests: XCTestCase {
    func testContinue_WhenTheRoleStepHasNoChoice_ShouldStayAndShowTheError() async {
        // Arrange
        let (viewModel, _) = await makeViewModel()

        // Act
        await viewModel.continueTapped()

        // Assert
        XCTAssertEqual(viewModel.step, .role)
        XCTAssertNotNil(viewModel.errors[.role])
    }

    func testChoose_WhenTheTeamIsFull_ShouldNotPickIt() async {
        // Arrange
        let (viewModel, _) = await makeViewModel()

        // Act
        viewModel.choose(.team("logistics"))

        // Assert
        XCTAssertNil(viewModel.form.role)
    }

    func testRegister_WhenEveryStepIsFilledIn_ShouldSendOnceAndReachDone() async throws {
        // Arrange
        let (viewModel, client) = await makeViewModel()

        // Act
        try await fillAndSign(viewModel)

        // Assert
        XCTAssertEqual(viewModel.step, .done)
        XCTAssertEqual(viewModel.result?.status, .pending)
        XCTAssertEqual(viewModel.result?.reference, "CD-0187")
        let sent = client.requests.filter { $0.method == .post }
        XCTAssertEqual(sent.count, 1)
        let body = try XCTUnwrap(sent.first?.body
            .flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        XCTAssertEqual(body["phone"] as? String, "09175550142")
        XCTAssertEqual(body["role"] as? String, "film")
    }

    func testRegister_WhenSubmitIsTappedTwice_ShouldMakeOneRegistration() async throws {
        // Arrange
        let gate = Gate()
        let (viewModel, client) = await makeViewModel { endpoint in
            if endpoint.method == .post {
                await gate.wait()
            }
            return try await SampleStub.handle(endpoint)
        }
        try await fillToWaiver(viewModel)

        // Act
        let first = Task { await viewModel.continueTapped() }
        while viewModel.sendState != .sending {
            await Task.yield()
        }
        await viewModel.continueTapped()
        await gate.open()
        await first.value

        // Assert
        XCTAssertEqual(client.requests.filter { $0.method == .post }.count, 1)
        XCTAssertEqual(viewModel.step, .done)
    }

    func testRegister_WhenOffline_ShouldKeepEverythingTypedAndRetryWithTheSameKey() async throws {
        // Arrange
        let attempts = Counter()
        let (viewModel, client) = await makeViewModel { endpoint in
            if endpoint.method == .post, attempts.next() == 1 {
                throw NetworkError.noConnection
            }
            return try await SampleStub.handle(endpoint)
        }
        try await fillToWaiver(viewModel)
        let typed = viewModel.form

        // Act
        await viewModel.continueTapped()
        let afterFailure = viewModel.sendState
        await viewModel.continueTapped()

        // Assert
        guard case .failed = afterFailure
        else { return XCTFail("expected a failed send, got \(afterFailure)") }
        XCTAssertEqual(viewModel.form, typed)
        XCTAssertEqual(viewModel.step, .done)
        let keys = client.requests.filter { $0.method == .post }
            .map { $0.headers["Idempotency-Key"] }
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(keys.first, keys.last, "a retry must not register twice")
    }

    func testRegister_WhenTheLastSlotIsTaken_ShouldOfferTheWaitingListAndJoinIt() async throws {
        // Arrange
        let (viewModel, client) = await makeViewModel(id: "behia-lastslot")
        try await fillToWaiver(viewModel)

        // Act
        await viewModel.continueTapped()
        let afterTaken = viewModel.sendState
        await viewModel.joinWaitingList()

        // Assert
        XCTAssertEqual(afterTaken, .lastSlotTaken)
        XCTAssertEqual(viewModel.result?.status, .waitlisted)
        let keys = client.requests.filter { $0.method == .post }
            .map { $0.headers["Idempotency-Key"] }
        XCTAssertNotEqual(keys.first, keys.last, "joining the waiting list is a new request")
    }

    func testBack_WhenTheLastSlotWasTaken_ShouldClearItSoTheStepCanContinue() async throws {
        // Arrange
        let (viewModel, _) = await makeViewModel(id: "behia-lastslot")
        try await fillToWaiver(viewModel)
        await viewModel.continueTapped()

        // Act
        viewModel.back()

        // Assert
        XCTAssertEqual(viewModel.step, .details)
        XCTAssertEqual(viewModel.sendState, .idle)
    }

    func testPayViewModel_WhenAskedTwice_ShouldBeTheSameOneSoSentIsKept() async throws {
        // Arrange
        let (viewModel, _) = await makeViewModel()
        try await fillAndSign(viewModel)

        // Act
        let first = viewModel.payViewModel()
        let second = viewModel.payViewModel()

        // Assert
        XCTAssertNotNil(first)
        XCTAssertTrue(first === second)
    }

    func testRegistrationSheet_WhenPresentedThenDismissed_ShouldFreeBothViewModels() async throws {
        // Arrange: a window to present on, as the app does over Trip detail.
        let window = try makeWindow()
        weak var weakRegistration: RegistrationViewModel?
        weak var weakPay: PayTripViewModel?

        // Act: present the sheet at its Done step, push Pay on top, then dismiss it.
        do {
            let (viewModel, _) = await makeViewModel()
            try await fillAndSign(viewModel)
            let pay = try XCTUnwrap(viewModel.payViewModel())
            let sheet = UIHostingController(rootView: RegistrationView(viewModel: viewModel) { _ in
            }
            .theme(.crossdrive))
            let payScreen = UIHostingController(rootView: NavigationStack {
                PayTripView(viewModel: pay, onDone: {})
            }.theme(.crossdrive))
            try await present(sheet, on: XCTUnwrap(window.rootViewController))
            await present(payScreen, on: sheet)
            try await dismiss(XCTUnwrap(window.rootViewController))
            weakRegistration = viewModel
            weakPay = pay
        }
        for _ in 0 ..< 100 where weakRegistration != nil || weakPay != nil {
            await Task.yield()
        }

        // Assert
        XCTAssertNil(
            weakRegistration,
            "the registration sheet keeps its view model after it is dismissed"
        )
        XCTAssertNil(weakPay, "the pay screen keeps its view model after it is dismissed")
        window.isHidden = true
    }

    func testSteps_ForACamp_ShouldStartOnDetailsWithNoRole() async throws {
        // Arrange
        let (viewModel, client) = await makeViewModel(id: "camp-feb")

        // Act
        fillDetails(viewModel)
        await viewModel.continueTapped()
        viewModel.form.signature = "Joy Bañares"
        await viewModel.continueTapped()

        // Assert
        XCTAssertEqual(viewModel.steps, [.details, .waiver, .done])
        XCTAssertEqual(viewModel.step, .done)
        let body = try XCTUnwrap(client.requests.last?.body.flatMap {
            try JSONSerialization.jsonObject(with: $0) as? [String: Any]
        })
        XCTAssertNil(body["role"])
    }

    func testHasUnsavedChanges_WhenSomethingIsTypedAndBeforeRegistering_ShouldBeTrue() async {
        // Arrange
        let (viewModel, _) = await makeViewModel()

        // Act
        let before = viewModel.hasUnsavedChanges
        viewModel.form.mobile = "0917"

        // Assert
        XCTAssertFalse(before)
        XCTAssertTrue(viewModel.hasUnsavedChanges)
    }

    // MARK: - Helpers

    private func makeWindow() throws -> UIWindow {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "the tests run inside the app, which has a window scene"
        )
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        return window
    }

    private func present(_ controller: UIViewController, on presenter: UIViewController) async {
        await withCheckedContinuation { done in
            presenter.present(controller, animated: false) { done.resume() }
        }
    }

    private func dismiss(_ presenter: UIViewController) async {
        await withCheckedContinuation { done in
            presenter.dismiss(animated: false) { done.resume() }
        }
    }

    private func makeViewModel(
        id: String = "behia",
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse = SampleStub.handle
    ) async -> (RegistrationViewModel, StubHTTPClient) {
        let client = StubHTTPClient(handler)
        let api = EventsAPI(client: client)
        let detail = try? await EventsAPI(client: StubHTTPClient(SampleStub.handle)).event(id: id)
        let viewModel = RegistrationViewModel(
            detail: detail ?? Self.missing,
            api: api,
            imageLoader: FakeImageLoader()
        )
        return (viewModel, client)
    }

    private static let missing = EventDetail(
        event: Event.placeholders[0], summary: "", background: "", photoURLs: [], roles: [],
        covers: [], bringList: []
    )

    private func fillDetails(_ viewModel: RegistrationViewModel) {
        viewModel.form.mobile = "0917 555 0142"
        viewModel.form.emergencyName = "Liza Bañares"
        viewModel.form.emergencyMobile = "0917 555 0199"
    }

    private func fillToWaiver(_ viewModel: RegistrationViewModel) async throws {
        viewModel.choose(.team("film"))
        await viewModel.continueTapped()
        fillDetails(viewModel)
        await viewModel.continueTapped()
        viewModel.form.signature = "Joy Bañares"
        XCTAssertEqual(viewModel.step, .waiver)
    }

    private func fillAndSign(_ viewModel: RegistrationViewModel) async throws {
        try await fillToWaiver(viewModel)
        await viewModel.continueTapped()
    }
}
