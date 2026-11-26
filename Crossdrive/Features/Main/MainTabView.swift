import DesignSystem
import SwiftUI

/// The guest or signed-in home: five peer tabs, each with its own stack. The
/// selected tab and the Events stack live on the coordinator, so a link or a
/// notification can open the right place.
/// Tapping the tab you are already on pops it back to its root.
struct MainTabView: View {
    @Bindable private var coordinator: AppCoordinator
    @State private var models: MainTabModels

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        let models = MainTabModels(container: coordinator.container)
        models.isSignedIn = { [weak coordinator] in coordinator?.session.user != nil }
        _models = State(initialValue: models)
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView(
                viewModel: models.home,
                makeMyTrip: models.myTripView,
                path: $coordinator.homePath
            )
            .tabItem { Label(MainTab.home.title, image: MainTab.home.iconName) }
            .tag(MainTab.home)

            EventsView(
                viewModel: models.events,
                myTrips: models.myTrips,
                isSignedIn: coordinator.session.user != nil,
                makeMyTrip: models.myTripView,
                path: $coordinator.eventsPath
            )
            .tabItem { Label(MainTab.events.title, image: MainTab.events.iconName) }
            .tag(MainTab.events)

            MinistriesView(
                viewModel: models.ministries,
                path: $coordinator.ministriesPath,
                makeDetail: { id in
                    MinistryDetailViewModel(
                        api: coordinator.container.ministriesAPI,
                        ministryID: id,
                        reporter: coordinator.container.services.crashReporter
                    )
                }
            )
            .tabItem { Label(MainTab.ministries.title, image: MainTab.ministries.iconName) }
            .tag(MainTab.ministries)

            emptyTab(
                .pray,
                message: "Prayer points will show here.",
                systemImage: "heart"
            )

            NavigationStack {
                MoreView(coordinator: coordinator, myTrips: models.myTrips)
                    .navigationTitle(MainTab.profile.title)
                    .navigationDestination(for: EventsRoute.self) { route in
                        switch route {
                        case let .myTrip(id): models.myTripView(id)
                        case let .detail(id):
                            EventDetailView(
                                viewModel: models.events.detailViewModel(for: id),
                                onOpenTrip: { coordinator.openMyTrip(id) }
                            )
                        }
                    }
            }
            .tabItem { Label(MainTab.profile.title, image: MainTab.profile.iconName) }
            .tag(MainTab.profile)
        }
    }

    /// A tab that has no feature yet: its name and one calm sentence.
    private func emptyTab(_ tab: MainTab, message: String, systemImage: String) -> some View {
        NavigationStack {
            DSStateView("Nothing here yet", message: message, systemImage: systemImage)
                .navigationTitle(tab.title)
        }
        .tabItem { Label(tab.title, image: tab.iconName) }
        .tag(tab)
    }

    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { coordinator.selectedTab },
            set: { newValue in
                if newValue == coordinator.selectedTab {
                    switch newValue {
                    case .home: coordinator.homePath.removeAll()
                    case .events: coordinator.eventsPath.removeAll()
                    case .ministries: coordinator.ministriesPath.removeAll()
                    case .pray, .profile: break
                    }
                }
                coordinator.selectedTab = newValue
            }
        )
    }
}

#Preview {
    MainTabView(coordinator: AppCoordinator(container: .preview()))
        .theme(.crossdrive)
}
