import SwiftUI

/// The guest or signed-in home: peer tabs, each with its own stack. The
/// selected tab and the Items stack live on the coordinator, so a link or a
/// notification can open the right place.
/// Tapping the tab you are already on pops it back to its root.
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
            SampleListView(viewModel: sampleViewModel, path: $coordinator.itemsPath)
                .tabItem { Label("Items", systemImage: "list.bullet") }
                .tag(MainTab.items)

            NavigationStack {
                MoreView(coordinator: coordinator)
            }
            .tabItem { Label("More", systemImage: "ellipsis") }
            .tag(MainTab.more)
        }
    }

    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { coordinator.selectedTab },
            set: { newValue in
                if newValue == coordinator.selectedTab, newValue == .items {
                    coordinator.itemsPath.removeAll()
                }
                coordinator.selectedTab = newValue
            }
        )
    }
}

#Preview {
    MainTabView(coordinator: AppCoordinator(container: .preview()))
        .theme(.system)
}
