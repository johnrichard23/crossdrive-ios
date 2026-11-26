@testable import Crossdrive
import DataLayer
import XCTest

@MainActor
final class MyTripViewModelTests: XCTestCase {
    func testLoad_WhenGoing_ShouldShowTheTripAndItsToDos() async throws {
        // Arrange
        let viewModel = makeViewModel(tripID: "behia-going")

        // Act
        await viewModel.load()

        // Assert
        let trip = try XCTUnwrap(viewModel.state.value)
        XCTAssertEqual(trip.event.name, "Behia Mission Trip")
        XCTAssertEqual(trip.toDos.count, 2)
    }

    func testLoad_WhenOfflineWithASavedTrip_ShouldShowIt() async throws {
        // Arrange: the trip loaded once, then the signal is gone.
        let calls = Counter()
        let client = StubHTTPClient { endpoint in
            guard calls.next() == 1 else { throw NetworkError.noConnection }
            return try await SampleStub.handle(endpoint)
        }
        let container = DependencyContainer.preview(client: client)
        _ = try await container.myTrips.all()
        let viewModel = MyTripViewModel(tripID: "behia-going", container: container)

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state.value?.id, "behia-going")
    }

    func testLoad_WhenOfflineWithNothingSaved_ShouldShowOffline() async {
        // Arrange
        let viewModel = makeViewModel(
            tripID: "behia-going",
            client: StubHTTPClient { _ in throw NetworkError.noConnection }
        )

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state, .offline)
    }

    func testUpNext_WhenPending_ShouldBeNil() async {
        // Arrange: the camp registration still waits for a coordinator.
        let viewModel = makeViewModel(tripID: "camp-feb")

        // Act
        await viewModel.load()

        // Assert
        XCTAssertNil(viewModel.upNext)
    }

    func testUpNext_WhenGoingTheDayBefore_ShouldBeTheBoat() async throws {
        // Arrange
        let now = try Date("2026-12-11T20:00:00+08:00", strategy: .iso8601)
        let viewModel = makeViewModel(tripID: "behia-going", now: now)

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.upNext?.title, "Boat to Bagatao Island")
    }

    // MARK: - Packing

    func testToggle_WhenOnline_ShouldFlipAtOnceAndSendOnce() async {
        // Arrange: the tick's request waits until the test lets it go.
        let arrived = Gate()
        let release = Gate()
        let puts = Recorder<String>()
        let viewModel = makeViewModel(tripID: "behia-going", client: StubHTTPClient { endpoint in
            if endpoint.method == .put {
                puts.add(endpoint.path)
                await arrived.open()
                await release.wait()
            }
            return try await SampleStub.handle(endpoint)
        })
        await viewModel.load()

        // Act
        let tick = Task { await viewModel.toggle("clothes") }
        await arrived.wait()
        let flippedBeforeReply = viewModel.state.value?.packed.contains("clothes")
        await release.open()
        await tick.value

        // Assert
        XCTAssertEqual(flippedBeforeReply, true)
        XCTAssertEqual(viewModel.state.value?.packed.contains("clothes"), true)
        XCTAssertEqual(puts.values, ["me/registrations/reg-behia/packed/clothes"])
    }

    func testToggle_WhenServerFails_ShouldFlipBackAndShowToast() async {
        // Arrange
        let viewModel = makeViewModel(tripID: "behia-going", client: StubHTTPClient { endpoint in
            if endpoint.method == .put {
                throw NetworkError.server(status: 500, message: nil)
            }
            return try await SampleStub.handle(endpoint)
        })
        await viewModel.load()

        // Act
        await viewModel.toggle("water")

        // Assert: water was packed, and stays packed.
        XCTAssertEqual(viewModel.state.value?.packed.contains("water"), true)
        XCTAssertEqual(viewModel.toast?.message, "Couldn't save. Try again.")
    }

    func testToggle_WhenOffline_ShouldNotSendOrFlip() async {
        // Arrange
        let puts = Counter()
        let viewModel = makeViewModel(tripID: "behia-going", client: StubHTTPClient { endpoint in
            if endpoint.method == .put {
                _ = puts.next()
            }
            return try await SampleStub.handle(endpoint)
        })
        await viewModel.load()
        viewModel.isOnline = false

        // Act
        await viewModel.toggle("clothes")

        // Assert: the next call would be the first.
        XCTAssertEqual(viewModel.state.value?.packed.contains("clothes"), false)
        XCTAssertEqual(puts.next(), 1)
    }

    func testToggle_WhenTappedTwiceQuickly_ShouldSendOnce() async {
        // Arrange: the first tick's request is held.
        let arrived = Gate()
        let release = Gate()
        let puts = Recorder<String>()
        let viewModel = makeViewModel(tripID: "behia-going", client: StubHTTPClient { endpoint in
            if endpoint.method == .put {
                puts.add(endpoint.path)
                await arrived.open()
                await release.wait()
            }
            return try await SampleStub.handle(endpoint)
        })
        await viewModel.load()

        // Act
        let first = Task { await viewModel.toggle("clothes") }
        await arrived.wait()
        await viewModel.toggle("clothes")
        await release.open()
        await first.value

        // Assert
        XCTAssertEqual(puts.values.count, 1)
        XCTAssertEqual(viewModel.state.value?.packed.contains("clothes"), true)
    }

    func testToggle_WhenSaved_ShouldKeepTheTickForTheNextOfflineOpen() async {
        // Arrange: one container, so the second view model reads the same saved copy.
        let calls = Counter()
        let client = StubHTTPClient { endpoint in
            if endpoint.method == .get, calls.next() > 1 {
                throw NetworkError.noConnection
            }
            return try await SampleStub.handle(endpoint)
        }
        let container = DependencyContainer.preview(client: client)
        let first = MyTripViewModel(tripID: "behia-going", container: container)
        await first.load()
        await first.toggle("clothes")
        let second = MyTripViewModel(tripID: "behia-going", container: container)

        // Act
        await second.load()

        // Assert
        XCTAssertEqual(second.state.value?.packed.contains("clothes"), true)
    }

    func testLoad_WhenShownAgainAfterAnotherScreenTicked_ShouldShowTheTick() async {
        // Arrange: the tab's screen loaded, then the reminder sheet ticked an item.
        let container = DependencyContainer.preview(client: StubHTTPClient(SampleStub.handle))
        let tab = MyTripViewModel(tripID: "behia-going", container: container)
        await tab.load()
        let sheet = MyTripViewModel(tripID: "behia-going", container: container)
        await sheet.load()
        await sheet.toggle("clothes")

        // Act: the tab's screen appears again.
        await tab.load()

        // Assert
        XCTAssertEqual(tab.state.value?.packed.contains("clothes"), true)
    }

    func testLoad_WhenItLandsWhileATickIsSaving_ShouldKeepTheTick() async {
        // Arrange: the tick's request is held.
        let arrived = Gate()
        let release = Gate()
        let viewModel = makeViewModel(tripID: "behia-going", client: StubHTTPClient { endpoint in
            if endpoint.method == .put {
                await arrived.open()
                await release.wait()
            }
            return try await SampleStub.handle(endpoint)
        })
        await viewModel.load()
        let tick = Task { await viewModel.toggle("clothes") }
        await arrived.wait()

        // Act: a refresh finishes before the tick is saved.
        await viewModel.load(forceReload: true)
        let duringSave = viewModel.state.value?.packed.contains("clothes")
        await release.open()
        await tick.value

        // Assert
        XCTAssertEqual(duringSave, true)
        XCTAssertEqual(viewModel.state.value?.packed.contains("clothes"), true)
    }

    // MARK: - Reminder

    func testSetReminder_WhenPermissionDenied_ShouldStayOffAndAskForSettings() async {
        // Arrange: Bulan's reminder is off.
        let viewModel = makeViewModel(
            tripID: "bulan",
            push: FakePushRegistrar(current: .denied)
        )
        await viewModel.load()

        // Act
        await viewModel.setReminder(true)

        // Assert
        XCTAssertEqual(viewModel.state.value?.remindNightBefore, false)
        XCTAssertTrue(viewModel.reminderNeedsSettings)
    }

    func testSetReminder_WhenNotDeterminedThenAllowed_ShouldSendOn() async {
        // Arrange
        let puts = Recorder<String>()
        let push = FakePushRegistrar(current: .notDetermined, answerToPrompt: .authorized)
        let viewModel = makeViewModel(
            tripID: "bulan",
            client: StubHTTPClient { endpoint in
                if endpoint.method == .put {
                    puts.add(endpoint.path)
                }
                return try await SampleStub.handle(endpoint)
            },
            push: push
        )
        await viewModel.load()

        // Act
        await viewModel.setReminder(true)

        // Assert
        XCTAssertEqual(viewModel.state.value?.remindNightBefore, true)
        XCTAssertEqual(puts.values, ["me/registrations/reg-bulan/reminder"])
        let prompts = await push.promptCount
        XCTAssertEqual(prompts, 1)
    }

    func testSetReminder_WhenServerFails_ShouldTurnBackOffAndShowToast() async {
        // Arrange
        let viewModel = makeViewModel(
            tripID: "bulan",
            client: StubHTTPClient { endpoint in
                if endpoint.method == .put {
                    throw NetworkError.server(status: 500, message: nil)
                }
                return try await SampleStub.handle(endpoint)
            },
            push: FakePushRegistrar(current: .authorized)
        )
        await viewModel.load()

        // Act
        await viewModel.setReminder(true)

        // Assert
        XCTAssertEqual(viewModel.state.value?.remindNightBefore, false)
        XCTAssertEqual(viewModel.toast?.message, "Couldn't save. Try again.")
    }

    private func makeViewModel(
        tripID: Event.ID,
        client: StubHTTPClient = StubHTTPClient(SampleStub.handle),
        push: any PushRegistrar = FakePushRegistrar(current: .authorized),
        now: Date = Date(timeIntervalSince1970: 1_790_000_000)
    ) -> MyTripViewModel {
        var services = PlatformServices.preview
        services.push = push
        let container = DependencyContainer.preview(client: client, services: services)
        return MyTripViewModel(tripID: tripID, container: container, now: { now })
    }
}
