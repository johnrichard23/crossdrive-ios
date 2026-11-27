@testable import Crossdrive
import DataLayer
import XCTest

private let detailJSON = """
{
  "ministry": {"id": "m1", "name": "Bible studies", "schedule": "Every week"},
  "photos": [{"url": "https://example.com/a.jpg", "caption": "Reading"}, {"caption": "No url"}],
  "updates": [{"id": "u1", "text": "Done.", "postedAt": "2026-11-09T02:00:00Z"}, {"text": "No id"}],
  "prayer": {"id": "p1", "body": "For the families.", "prayedCount": 31},
  "need": {
    "title": "Bibles",
    "raised": {"amountMinor": 1200000, "currency": "PHP"},
    "goal": {"amountMinor": 3000000, "currency": "PHP"}
  }
}
"""

@MainActor
final class MinistryDetailViewModelTests: XCTestCase {
    func testLoad_WhenServerReturnsTheMinistry_ShouldKeepOnlyTheReadableParts() async {
        // Arrange
        let viewModel = makeViewModel { _ in .json(detailJSON) }

        // Act
        await viewModel.load()

        // Assert
        let detail = viewModel.state.value
        XCTAssertEqual(detail?.ministry.id, "m1")
        XCTAssertEqual(detail?.photos.map(\.caption), ["Reading"])
        XCTAssertEqual(detail?.updates.map(\.id), ["u1"])
        XCTAssertEqual(detail?.prayer?.prayedCount, 31)
        XCTAssertEqual(detail?.need?.fraction, 0.4)
    }

    func testLoad_WhenThePartsAreMissing_ShouldStillLoadTheMinistry() async {
        // Arrange
        let viewModel = makeViewModel { _ in
            .json(#"{"ministry": {"id": "m1", "name": "Bible studies"}}"#)
        }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state.value?.photos, [])
        XCTAssertNil(viewModel.state.value?.need)
    }

    func testLoad_WhenTheMinistryIsNotFound_ShouldBeUnavailable() async {
        // Arrange
        let viewModel = makeViewModel { _ in .json("{}", status: 404) }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertTrue(viewModel.isUnavailable)
    }

    func testLoad_WhenTheReplyHasNoReadableMinistry_ShouldBeUnavailable() async {
        // Arrange
        let viewModel = makeViewModel { _ in .json("{}") }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertTrue(viewModel.isUnavailable)
    }

    func testLoad_WhenOffline_ShouldBeOfflineAndNotUnavailable() async {
        // Arrange
        let viewModel = makeViewModel { _ in throw NetworkError.noConnection }

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .offline)
        XCTAssertFalse(viewModel.isUnavailable)
    }

    func testFraction_WhenGoalIsZeroOrExceeded_ShouldStayBetweenZeroAndOne() {
        // Arrange
        let noGoal = MinistryNeed(
            title: "A", raised: Money(amountMinor: 100, currency: "PHP"),
            goal: Money(amountMinor: 0, currency: "PHP")
        )
        let over = MinistryNeed(
            title: "B", raised: Money(amountMinor: 500, currency: "PHP"),
            goal: Money(amountMinor: 100, currency: "PHP")
        )

        // Act and Assert
        XCTAssertEqual(noGoal.fraction, 0)
        XCTAssertEqual(over.fraction, 1)
    }

    func testDateLabel_WhenPostedLateAtNightUTC_ShouldUseManilaTime() {
        // Arrange: 22:00 UTC on Nov 8 is 06:00 on Nov 9 in Manila.
        let update = MinistryUpdate(
            id: "u", text: "t", postedAt: ISO8601DateFormatter().date(from: "2026-11-08T22:00:00Z")
        )

        // Act and Assert
        XCTAssertEqual(update.dateLabel, "Nov 9")
    }

    // MARK: - Its own page

    func testLoad_ForEachMinistryOnTheList_ShouldShowItsOwnPage() async {
        // Arrange
        let cases: [(id: String, name: String)] = [
            ("bible-studies", "Gatbo"),
            ("crochet", "Crochet"),
            ("school-fund", "School fund"),
        ]

        for item in cases {
            let viewModel = makeViewModel(id: item.id, SampleStub.handle)

            // Act
            await viewModel.load()

            // Assert
            XCTAssertEqual(viewModel.state.value?.ministry.name, item.name, item.id)
        }
    }

    func testLoad_WhenTheMinistryIsNotOnTheList_ShouldBeUnavailable() async {
        // Arrange
        let viewModel = makeViewModel(id: "taken-down", SampleStub.handle)

        // Act
        await viewModel.load()

        // Assert
        XCTAssertTrue(viewModel.isUnavailable)
    }

    // MARK: - Photo

    func testLoad_WithAPhotoSize_ShouldWaitForThePhotoBeforeShowingThePage() async {
        // Arrange: the ministry has a photo, which arrives only when the test lets it.
        let withPhoto = detailJSON.replacingOccurrences(
            of: #""schedule": "Every week"}"#,
            with: #""schedule": "Every week", "imageURL": "https://example.com/hero.jpg"}"#
        )
        let asked = Gate()
        let release = Gate()
        let viewModel = makeViewModel(
            { _ in .json(withPhoto) },
            imageLoader: FakeImageLoader {
                await asked.open()
                await release.wait()
            }
        )

        // Act
        let loading = Task { await viewModel.load(heroPixels: 100) }
        await asked.wait()
        let shownBeforePhoto = viewModel.state.value != nil
        await release.open()
        await loading.value

        // Assert
        XCTAssertFalse(shownBeforePhoto)
        XCTAssertNotNil(viewModel.state.value)
        XCTAssertNotNil(viewModel.heroImage)
    }

    // MARK: - I prayed

    func testPray_WhenSaved_ShouldCountOneMoreAndSendOnce() async {
        // Arrange
        let posts = Counter()
        let viewModel = makeViewModel { endpoint in
            if endpoint.method == .post {
                _ = posts.next()
            }
            return .json(endpoint.method == .post ? "{}" : detailJSON)
        }
        await viewModel.load()

        // Act: tapped twice.
        await viewModel.pray()
        await viewModel.pray()

        // Assert
        XCTAssertTrue(viewModel.hasPrayed)
        XCTAssertEqual(viewModel.state.value?.prayer?.prayedCount, 32)
        XCTAssertEqual(posts.next(), 2)
    }

    func testPray_WhenTheServerFails_ShouldTakeItBackAndShowAToast() async {
        // Arrange
        let viewModel = makeViewModel { endpoint in
            if endpoint.method == .post {
                throw NetworkError.noConnection
            }
            return .json(detailJSON)
        }
        await viewModel.load()

        // Act
        await viewModel.pray()

        // Assert
        XCTAssertFalse(viewModel.hasPrayed)
        XCTAssertEqual(viewModel.state.value?.prayer?.prayedCount, 31)
        XCTAssertNotNil(viewModel.toast)
    }

    func testPray_WhenOffline_ShouldNotSendOrCount() async {
        // Arrange
        let posts = Counter()
        let viewModel = makeViewModel { endpoint in
            if endpoint.method == .post {
                _ = posts.next()
            }
            return .json(detailJSON)
        }
        await viewModel.load()
        viewModel.isOnline = false

        // Act
        await viewModel.pray()

        // Assert
        XCTAssertFalse(viewModel.hasPrayed)
        XCTAssertEqual(viewModel.state.value?.prayer?.prayedCount, 31)
        XCTAssertEqual(posts.next(), 1)
        XCTAssertNotNil(viewModel.toast)
    }

    private func makeViewModel(
        id: Ministry.ID = "m1",
        _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse,
        imageLoader: any ImageLoading = FakeImageLoader()
    ) -> MinistryDetailViewModel {
        MinistryDetailViewModel(
            api: MinistriesAPI(client: StubHTTPClient(handler)),
            ministryID: id,
            imageLoader: imageLoader,
            mediaDeadline: { try? await Task.sleep(for: .seconds(3600)) }
        )
    }
}
