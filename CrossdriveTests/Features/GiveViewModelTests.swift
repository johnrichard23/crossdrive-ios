@testable import Crossdrive
import DataLayer
import XCTest

@MainActor
final class GiveViewModelTests: XCTestCase, GiveTestRig {
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
        // Arrange: only the two real endpoints answer.
        let paths = Recorder<String>()
        let viewModel = makeViewModel(userName: "Joy Santos") { endpoint in
            paths.add(endpoint.path)
            switch endpoint.path {
            case "ministries/school-fund/pledges": return .json(pledgeJSON)
            case "pledges/CD-0142/sent": return .json("{}")
            default: return .json("{}", status: 404)
            }
        }
        await viewModel.continueTapped()

        // Act
        await viewModel.markSent()

        // Assert
        XCTAssertEqual(paths.values, ["ministries/school-fund/pledges", "pledges/CD-0142/sent"])
        XCTAssertEqual(viewModel.step, .thanks)
        XCTAssertEqual(viewModel.thanksTitle, "Salamat, Joy")
    }

    func testContinueTapped_WhenTheServerSavedAnotherGift_ShouldShowTheSavedOne() async {
        // Arrange: a retry is answered with the ₱800 pledge saved first.
        let saved = pledgeJSON.replacingOccurrences(
            of: #""reference": "CD-0142","#,
            with: #""reference": "CD-0142", "frequency": "monthly", "amountMinor": 80000,"#
        )
        let viewModel = makeViewModel { _ in .json(saved) }
        viewModel.choose(1200)

        // Act
        await viewModel.continueTapped()

        // Assert
        XCTAssertEqual(viewModel.savedGift, Gift(frequency: .monthly, pesos: 800))
        XCTAssertEqual(
            viewModel.pledgeLead,
            "Your pledge is saved. It starts when we get your first ₱800."
        )
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
}
