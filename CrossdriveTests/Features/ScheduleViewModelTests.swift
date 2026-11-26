@testable import Crossdrive
import DataLayer
import XCTest

@MainActor
final class ScheduleViewModelTests: XCTestCase {
    func testLoad_WhenPending_ShouldBeNotConfirmed() async {
        // Arrange: the camp registration still waits for a coordinator.
        let viewModel = makeViewModel(tripID: "camp-feb")

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.content, .notConfirmed)
    }

    func testLoad_WhenUnpublished_ShouldBeNotPublished() async {
        // Arrange: going, but the coordinators have not published the schedule.
        let json = SampleStub.myTripsJSON.replacingOccurrences(
            of: #""published": true"#,
            with: #""published": false"#
        )
        let viewModel = makeViewModel(
            tripID: "behia-going",
            client: StubHTTPClient { _ in .json(json) }
        )

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.content, .notPublished)
    }

    func testLoad_WhenGoingDuringTheTrip_ShouldSelectToday() async throws {
        // Arrange: the second morning of the trip.
        let now = try Date("2026-12-13T08:00:00+08:00", strategy: .iso8601)
        let viewModel = makeViewModel(tripID: "behia-going", now: now)

        // Act
        await viewModel.load()

        // Assert
        let timeline = try XCTUnwrap(viewModel.timeline)
        XCTAssertEqual(viewModel.selectedDay, timeline.days[1].id)
    }

    func testLoad_WhenOfflineWithNothingSaved_ShouldBeOffline() async {
        // Arrange
        let viewModel = makeViewModel(
            tripID: "behia-going",
            client: StubHTTPClient { _ in throw NetworkError.noConnection }
        )

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.content, .offline)
    }

    func testLoad_WhenReloaded_ShouldKeepThePickedDay() async throws {
        // Arrange: the person picked day 3, then pulled to refresh.
        let now = try Date("2026-12-13T08:00:00+08:00", strategy: .iso8601)
        let viewModel = makeViewModel(tripID: "behia-going", now: now)
        await viewModel.load()
        let lastDay = try XCTUnwrap(viewModel.timeline?.days.last?.id)
        viewModel.selectedDay = lastDay

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.selectedDay, lastDay)
    }

    func testStartOnToday_WhenOpenedAgainAfterPickingADay_ShouldBeToday() async throws {
        // Arrange: day 3 was picked on an earlier visit, on the second morning.
        let now = try Date("2026-12-13T08:00:00+08:00", strategy: .iso8601)
        let viewModel = makeViewModel(tripID: "behia-going", now: now)
        await viewModel.load()
        let timeline = try XCTUnwrap(viewModel.timeline)
        viewModel.selectedDay = timeline.days[2].id

        // Act
        viewModel.startOnToday()

        // Assert
        XCTAssertEqual(viewModel.selectedDay, timeline.days[1].id)
    }

    func testTeamLabel_ForEachTeam_ShouldNameYourOwnTeam() async throws {
        // Arrange: the person is on the film crew.
        let viewModel = makeViewModel(tripID: "behia-going")
        await viewModel.load()
        let items = try XCTUnwrap(viewModel.timeline?.days.first?.items)
        let cases: [(id: String, tag: ScheduleViewModel.TeamTag)] = [
            ("settle", .init(label: "Everyone", isMine: false)),
            ("kids", .init(label: "Kids' camp", isMine: false)),
            ("film", .init(label: "Film crew · your team", isMine: true)),
        ]

        for item in cases {
            // Act
            let schedule = try XCTUnwrap(items.first { $0.id == item.id })
            let tag = viewModel.teamTag(for: schedule)

            // Assert
            XCTAssertEqual(tag, item.tag, item.id)
        }
    }

    func testItemAfter_WhenTheFilmWorkshop_ShouldBeLunch() async {
        // Arrange
        let viewModel = makeViewModel(tripID: "behia-going")
        await viewModel.load()

        // Act
        let after = viewModel.item(after: "film")

        // Assert
        XCTAssertEqual(after?.title, "Lunch with the families")
    }

    private func makeViewModel(
        tripID: Event.ID,
        client: StubHTTPClient = StubHTTPClient(SampleStub.handle),
        now: Date = Date(timeIntervalSince1970: 1_790_000_000)
    ) -> ScheduleViewModel {
        let container = DependencyContainer.preview(client: client)
        return ScheduleViewModel(tripID: tripID, repository: container.myTrips, now: { now })
    }
}
