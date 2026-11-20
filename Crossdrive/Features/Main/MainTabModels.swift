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

    private(set) lazy var ministries = MinistriesViewModel(
        api: container.ministriesAPI,
        reporter: container.services.crashReporter
    )
}
