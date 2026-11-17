import DesignSystem
import SwiftUI

/// The guest or signed-in home: five peer tabs, each with its own stack. The
/// selected tab lives on the coordinator, so a link or a notification can open
/// the right place. Tapping the tab you are already on pops it back to its root.
struct MainTabView: View {
    @Bindable private var coordinator: AppCoordinator
    @State private var sampleViewModel: SampleListViewModel

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        _sampleViewModel = State(
            initialValue: SampleListViewModel(
                api: coordinator.container.sampleAPI,
                reporter: coordinator.container.services.crashReporter
            )
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            emptyTab(.home, message: "Your next trip and today's prayer point will show here.")
            eventsTab
            emptyTab(.ministries, message: "Our ministries will show here.")
            emptyTab(.pray, message: "Prayer points will show here.")

            NavigationStack {
                MoreView(coordinator: coordinator)
            }
            .tabItem { Label(MainTab.profile.title, image: MainTab.profile.iconName) }
            .tag(MainTab.profile)
        }
    }

    /// Events has no feature yet. Until it does, links to the baseplate's sample
    /// items open here, so a link or a notification still lands on its screen.
    private var eventsTab: some View {
        NavigationStack(path: $coordinator.itemsPath) {
            DSStateView(
                "Nothing here yet",
                message: "Trips, camps and conferences will show here.",
                systemImage: "tray"
            )
            .navigationTitle(MainTab.events.title)
            .navigationDestination(for: SampleRoute.self) { route in
                switch route {
                case let .detail(id):
                    SampleDetailView(viewModel: sampleViewModel, itemID: id)
                }
            }
        }
        .task { await sampleViewModel.load() }
        .tabItem { Label(MainTab.events.title, image: MainTab.events.iconName) }
        .tag(MainTab.events)
    }

    /// Tapping the tab you are already on pops it back to its root.
    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { coordinator.selectedTab },
            set: { newValue in
                if newValue == coordinator.selectedTab, newValue == .events {
                    coordinator.itemsPath.removeAll()
                }
                coordinator.selectedTab = newValue
            }
        )
    }

    /// A tab that has no feature yet: its name and one calm sentence.
    private func emptyTab(_ tab: MainTab, message: String) -> some View {
        NavigationStack {
            DSStateView("Nothing here yet", message: message, systemImage: "tray")
                .navigationTitle(tab.title)
        }
        .tabItem { Label(tab.title, image: tab.iconName) }
        .tag(tab)
    }
}

#Preview {
    MainTabView(coordinator: AppCoordinator(container: .preview()))
        .theme(.crossdrive)
}
