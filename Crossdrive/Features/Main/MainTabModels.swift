/// The view models of the main tabs, each made the first time it is read.
///
/// SwiftUI may build a `MainTabView` value more than once (every time its
/// parent redraws) and keep only one of them. If the view models were built in
/// `init`, each of those builds would create a full set that nothing uses. Here
/// `init` makes nothing; the view models appear only when the tab view that
/// SwiftUI keeps reads them in its `body`.
@MainActor
final class MainTabModels {
    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
    }

    private(set) lazy var home = HomeViewModel(
        api: container.homeAPI,
        eventsAPI: container.eventsAPI,
        imageLoader: container.imageLoader,
        snapshotter: container.mapSnapshotter,
        reporter: container.services.crashReporter
    )

    private(set) lazy var events = EventsViewModel(
        api: container.eventsAPI,
        imageLoader: container.imageLoader,
        snapshotter: container.mapSnapshotter,
        reporter: container.services.crashReporter
    )

    /// Shared by Events › My events and Profile, so both show the same trips.
    private(set) lazy var myTrips = MyTripsViewModel(
        repository: container.myTrips,
        isSignedIn: { [weak self] in self?.isSignedIn() ?? false }
    )

    /// Set by the tab view from the coordinator's session.
    var isSignedIn: @MainActor () -> Bool = { false }

    /// One view model per trip, so a redraw of the stack does not build a new one.
    /// shortcut: kept until the tabs are rebuilt (sign-out); free them on pop if
    /// people open many trips.
    private var myTripModels: [Event.ID: MyTripViewModel] = [:]

    /// The My trip screen for one joined trip.
    func myTripView(_ id: Event.ID) -> MyTripView {
        let model = myTripModels[id] ?? MyTripViewModel(tripID: id, container: container)
        myTripModels[id] = model
        return MyTripView(
            viewModel: model,
            eventsAPI: container.eventsAPI,
            imageLoader: container.imageLoader
        )
    }

    private(set) lazy var ministries = MinistriesViewModel(
        api: container.ministriesAPI,
        reporter: container.services.crashReporter
    )
}
