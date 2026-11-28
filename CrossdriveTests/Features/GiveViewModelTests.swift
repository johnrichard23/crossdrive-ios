@testable import Crossdrive
import DataLayer
import XCTest

private let pledgeJSON = """
{"reference": "CD-0142", "gcashNumber": "0917 123 4567", "accountName": "CrossDrive Missions",
 "bankName": "BPI", "bankAccount": "1234 5678 90"}
"""

@MainActor
final class GiveViewModelTests: XCTestCase {
    // MARK: - Amount

    func testYearLine_ForEachMonthlyAmount_ShouldSayHowMuchOfAKidsYearItPays() {
        // Arrange
        let cases: [(pesos: Int, expected: String)] = [
            (800, "₱800 for 10 months is ₱8,000, one kid's school year."),
            (300, "₱300 for 10 months is ₱3,000, part of one kid's school year."),
            (1200, "₱1,200 for 10 months is ₱12,000, more than one kid's school year."),
        ]

        for item in cases {
            let viewModel = makeViewModel()

            // Act
            viewModel.choose(item.pesos)

            // Assert
            XCTAssertEqual(viewModel.yearLine, item.expected, "\(item.pesos)")
        }
    }

    func testYearLine_WhenTheMinistryIsNotTheSchoolFund_ShouldBeNil() {
        // Arrange
        let viewModel = makeViewModel(ministry: ministry(kind: .bibleStudy))

        // Act
        let line = viewModel.yearLine

        // Assert
        XCTAssertNil(line)
    }

    func testFrequencies_ForEachKind_ShouldOfferOneTimeOnlyOutsideTheSchoolFund() {
        // Arrange
        let school = makeViewModel()
        let bibleStudy = makeViewModel(ministry: ministry(kind: .bibleStudy))

        // Act
        let schoolOptions = school.frequencies
        let bibleStudyOptions = bibleStudy.frequencies

        // Assert
        XCTAssertEqual(schoolOptions, [.monthly, .yearly])
        XCTAssertEqual(bibleStudyOptions, [.monthly, .yearly, .once])
    }

    func testSetFrequency_WhenSwitchedToYearlyAndBack_ShouldScaleTheAmount() {
        // Arrange
        let viewModel = makeViewModel()

        // Act
        viewModel.setFrequency(.yearly)
        let yearly = (viewModel.pesos, viewModel.presets)
        viewModel.setFrequency(.monthly)

        // Assert
        XCTAssertEqual(yearly.0, 8000)
        XCTAssertEqual(yearly.1, [3000, 5000, 8000, 12000])
        XCTAssertEqual(viewModel.pesos, 800)
    }

    func testSetCustomAmount_ForEachEntry_ShouldTakeOnlyAWholeAmountFromTheMinimum() {
        // Arrange: `nil` means the entry is refused and ₱800 stays.
        let cases: [(text: String, taken: Int?)] = [
            ("1500", 1500),
            ("₱2,000", 2000),
            ("299", nil),
            ("abc", nil),
            ("", nil),
        ]

        for item in cases {
            let viewModel = makeViewModel()

            // Act
            let taken = viewModel.setCustomAmount(item.text)

            // Assert
            XCTAssertEqual(taken, item.taken != nil, item.text)
            XCTAssertEqual(viewModel.pesos, item.taken ?? 800, item.text)
        }
    }

    func testGiftFraction_WhenTheGiftIsMoreThanWhatIsLeft_ShouldStopAtTheGoal() {
        // Arrange: ₱96,000 of ₱160,000 is raised, so ₱64,000 is left.
        let viewModel = makeViewModel()

        // Act
        viewModel.choose(800)
        let oneKid = viewModel.giftFraction
        viewModel.setFrequency(.yearly)
        _ = viewModel.setCustomAmount("100000")

        // Assert
        XCTAssertEqual(oneKid, 0.05, accuracy: 0.0001)
        XCTAssertEqual(viewModel.giftFraction, 0.4, accuracy: 0.0001)
    }

    // MARK: - Pledge

    func testContinueTapped_WhenTappedTwiceQuickly_ShouldSendOnceAndShowThePledge() async {
        // Arrange
        let posts = Counter()
        let release = Gate()
        let viewModel = makeViewModel { _ in
            _ = posts.next()
            await release.wait()
            return .json(pledgeJSON)
        }

        // Act
        let first = Task { await viewModel.continueTapped() }
        await Task.yield()
        await viewModel.continueTapped()
        await release.open()
        await first.value

        // Assert
        XCTAssertEqual(viewModel.step, .pledge)
        XCTAssertEqual(viewModel.pledge?.reference, "CD-0142")
        XCTAssertEqual(posts.next(), 2)
    }

    func testContinueTapped_WhenTheServerFails_ShouldStayOnTheAmountWithAToast() async {
        // Arrange
        let viewModel = makeViewModel { _ in .json("{}", status: 500) }

        // Act
        await viewModel.continueTapped()

        // Assert
        XCTAssertEqual(viewModel.step, .amount)
        XCTAssertNotNil(viewModel.toast)
    }

    func testContinueTapped_WhenTheReplyHasNoReference_ShouldStayOnTheAmount() async {
        // Arrange
        let viewModel = makeViewModel { _ in .json(#"{"gcashNumber": "0917"}"#) }

        // Act
        await viewModel.continueTapped()

        // Assert
        XCTAssertEqual(viewModel.step, .amount)
        XCTAssertNil(viewModel.pledge)
    }

    func testContinueTapped_WhenOffline_ShouldNotSend() async {
        // Arrange
        let posts = Counter()
        let viewModel = makeViewModel { _ in
            _ = posts.next()
            return .json(pledgeJSON)
        }
        viewModel.isOnline = false

        // Act
        await viewModel.continueTapped()

        // Assert
        XCTAssertEqual(viewModel.step, .amount)
        XCTAssertNotNil(viewModel.toast)
        XCTAssertEqual(posts.next(), 1)
    }

    // MARK: - Sent

    func testMarkSent_WhenSaved_ShouldThankThePersonByFirstName() async {
        // Arrange
        let viewModel = makeViewModel(userName: "Joy Santos") { _ in .json(pledgeJSON) }
        await viewModel.continueTapped()

        // Act
        await viewModel.markSent()

        // Assert
        XCTAssertEqual(viewModel.step, .thanks)
        XCTAssertEqual(viewModel.thanksTitle, "Salamat, Joy")
    }

    func testMarkSent_WhenTheServerFails_ShouldStayOnThePledge() async {
        // Arrange
        let viewModel = makeViewModel { endpoint in
            endpoint.path.hasSuffix("/sent") ? .json("{}", status: 500) : .json(pledgeJSON)
        }
        await viewModel.continueTapped()

        // Act
        await viewModel.markSent()

        // Assert
        XCTAssertEqual(viewModel.step, .pledge)
        XCTAssertNotNil(viewModel.toast)
    }

    // MARK: - Sign in

    func testShowsSteps_WhenSignedIn_ShouldHideTheRowAndGoStraightToThePledge() async {
        // Arrange
        let viewModel = makeViewModel()

        // Act
        await viewModel.continueTapped()

        // Assert
        XCTAssertFalse(viewModel.showsSteps)
        XCTAssertEqual(viewModel.step, .pledge)
    }

    func testContinueTapped_WhenAGuestSignsIn_ShouldSaveThePledgeOnlyAfterSigningIn() async {
        // Arrange
        let posts = Counter()
        let signIn = SignInSpy()
        let viewModel = makeViewModel(signIn: signIn) { _ in
            _ = posts.next()
            return .json(pledgeJSON)
        }

        // Act
        await viewModel.continueTapped()
        let onSignInStep = (viewModel.step, viewModel.stepIndex, viewModel.signIn != nil)
        await signIn.finish()

        // Assert
        XCTAssertTrue(viewModel.showsSteps)
        XCTAssertEqual(viewModel.stepTitles, ["Amount", "Sign in", "Pledge"])
        XCTAssertEqual(onSignInStep.0, .signIn)
        XCTAssertEqual(onSignInStep.1, 1)
        XCTAssertTrue(onSignInStep.2)
        XCTAssertEqual(signIn.reminder?.title, "₱800 a month")
        XCTAssertEqual(viewModel.step, .pledge)
        XCTAssertEqual(viewModel.stepIndex, 2)
        XCTAssertEqual(posts.next(), 2)
    }

    func testBackToAmount_WhenAGuestLeavesSignIn_ShouldKeepTheAmountAndSaveNothing() async {
        // Arrange
        let posts = Counter()
        let viewModel = makeViewModel(signIn: SignInSpy()) { _ in
            _ = posts.next()
            return .json(pledgeJSON)
        }
        viewModel.choose(1200)
        await viewModel.continueTapped()

        // Act
        viewModel.backToAmount()

        // Assert
        XCTAssertEqual(viewModel.step, .amount)
        XCTAssertEqual(viewModel.pesos, 1200)
        XCTAssertNil(viewModel.signIn)
        XCTAssertEqual(posts.next(), 1)
    }

    func testBackToAmount_WhenTheSignInFinishesAfterwards_ShouldDropItAndSaveNothing() async {
        // Arrange: the guest leaves the sign-in step while it is still sending.
        let posts = Counter()
        let signIn = SignInSpy()
        let viewModel = makeViewModel(signIn: signIn) { _ in
            _ = posts.next()
            return .json(pledgeJSON)
        }
        await viewModel.continueTapped()
        viewModel.backToAmount()

        // Act
        let wentOn = await signIn.finish()

        // Assert
        XCTAssertFalse(wentOn)
        XCTAssertEqual(viewModel.step, .amount)
        XCTAssertEqual(posts.next(), 1)
    }

    func testContinueTapped_WhenTheAmountChangesAfterAFailure_ShouldUseANewKey() async {
        // Arrange: every save fails, so each Continue sends again.
        let keys = Recorder<String>()
        let viewModel = makeViewModel { endpoint in
            keys.add(endpoint.headers["Idempotency-Key"] ?? "")
            return .json("{}", status: 500)
        }

        // Act
        await viewModel.continueTapped()
        await viewModel.continueTapped()
        viewModel.choose(1200)
        await viewModel.continueTapped()

        // Assert
        XCTAssertEqual(keys.values.count, 3)
        XCTAssertEqual(keys.values[0], keys.values[1])
        XCTAssertNotEqual(keys.values[1], keys.values[2])
    }

    func testContinueTapped_WhenTheSignedInGuestsPledgeFails_ShouldNotAskToSignInAgain() async {
        // Arrange: the pledge fails once, then saves.
        let posts = Counter()
        let signIn = SignInSpy()
        let viewModel = makeViewModel(signIn: signIn) { _ in
            posts.next() == 1 ? .json("{}", status: 500) : .json(pledgeJSON)
        }
        await viewModel.continueTapped()
        await signIn.finish()
        let afterFailure = viewModel.step

        // Act
        await viewModel.continueTapped()

        // Assert
        XCTAssertEqual(afterFailure, .amount)
        XCTAssertEqual(viewModel.step, .pledge)
        XCTAssertEqual(viewModel.stepTitles, ["Amount", "Sign in", "Pledge"])
    }

    // MARK: - Helpers

    private func ministry(kind: Ministry.Kind = .school) -> Ministry {
        Ministry(
            id: "school-fund",
            name: "School fund",
            schedule: nil,
            place: "Gatbo and Bacon",
            summary: "",
            imageURL: nil,
            kind: kind,
            fund: kind == .school ? Ministry.Fund(
                kidsPaid: 12,
                kidsGoal: 20,
                raised: Money(amountMinor: 9_600_000, currency: "PHP"),
                goal: Money(amountMinor: 16_000_000, currency: "PHP"),
                costs: [
                    .init(title: "School fees", amount: Money(amountMinor: 45000, currency: "PHP")),
                    .init(
                        title: "Jeepney fare",
                        amount: Money(amountMinor: 25000, currency: "PHP")
                    ),
                    .init(title: "Notebooks", amount: Money(amountMinor: 10000, currency: "PHP")),
                ]
            ) : nil
        )
    }

    private func makeViewModel(
        ministry: Ministry? = nil,
        userName: String? = nil,
        signIn: SignInSpy? = nil,
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse = { _ in
            .json(pledgeJSON)
        }
    ) -> GiveViewModel {
        GiveViewModel(
            ministry: ministry ?? self.ministry(),
            api: MinistriesAPI(client: StubHTTPClient(handler)),
            userName: { userName },
            makeSignIn: signIn.map { spy in { spy.make(reminder: $0, isWanted: $1, then: $2) } }
        )
    }
}

/// Stands in for the coordinator's sign-in screen: keeps what it was given so
/// the test can finish the sign-in when it likes.
@MainActor
private final class SignInSpy {
    private(set) var reminder: GateTrip?
    private var isWanted: (@MainActor () -> Bool)?
    private var then: (@MainActor () async -> Void)?

    func make(
        reminder: GateTrip,
        isWanted: @escaping @MainActor () -> Bool,
        then: @escaping @MainActor () async -> Void
    ) -> EntryViewModel {
        self.reminder = reminder
        self.isWanted = isWanted
        self.then = then
        return makeEntryRig(trip: reminder).viewModel
    }

    /// Finishes the sign-in as the coordinator does: only while it is still wanted.
    /// Returns whether it went on.
    @discardableResult
    func finish() async -> Bool {
        guard isWanted?() == true else { return false }
        await then?()
        return true
    }
}
