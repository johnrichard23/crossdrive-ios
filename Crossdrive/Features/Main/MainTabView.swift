import DesignSystem
import SwiftUI

/// The guest or signed-in home: five peer tabs, each with its own stack. The
/// selected tab lives on the coordinator, so a link or a notification can open
/// the right place. Tapping the tab you are already on pops it back to its root.
struct MainTabView: View {
    @Bindable private var coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            emptyTab(.home, message: "Your next trip and today's prayer point will show here.")
            emptyTab(.events, message: "Trips, camps and conferences will show here.")
            emptyTab(.ministries, message: "Our ministries will show here.")
            emptyTab(.pray, message: "Prayer points will show here.")

            NavigationStack {
                MoreView(coordinator: coordinator)
                    .navigationTitle(MainTab.profile.title)
            }
            .tabItem { Label(MainTab.profile.title, image: MainTab.profile.iconName) }
            .tag(MainTab.profile)
        }
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
