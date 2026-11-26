import DesignSystem
import SwiftUI
import UIKit

/// Account, notifications and build information. A project replaces the build
/// section with its own settings.
struct MoreView: View {
    let coordinator: AppCoordinator
    let myTrips: MyTripsViewModel

    @State private var permission: NotificationPermissionViewModel
    @State private var showsPrePrompt = false
    @State private var isSigningOut = false

    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    init(coordinator: AppCoordinator, myTrips: MyTripsViewModel) {
        self.coordinator = coordinator
        self.myTrips = myTrips
        _permission = State(
            initialValue: NotificationPermissionViewModel(
                push: coordinator.container.services.push
            )
        )
    }

    private var container: DependencyContainer {
        coordinator.container
    }

    var body: some View {
        List {
            if container.features.authentication != .none {
                Section {
                    accountRows
                } header: {
                    DSSectionHeader("Account")
                }
                .dsListRows()
            }

            if coordinator.session.user != nil {
                Section {
                    myEventsRows
                } header: {
                    DSSectionHeader("My events")
                }
                .dsListRows()
            }

            Section {
                notificationRows
            } header: {
                DSSectionHeader("Notifications")
            }
            .dsListRows()

            Section {
                row("Environment", value: container.environment.kind.rawValue.capitalized)
                row("Server", value: container.environment.apiBaseURL.host() ?? "")
            } header: {
                DSSectionHeader("This build")
            }
            .dsListRows()

            #if DEBUG || STAGING
                Section {
                    NavigationLink("Debug menu") { DebugMenuView(coordinator: coordinator) }
                } header: {
                    DSSectionHeader("Developer")
                }
                .dsListRows()
            #endif
        }
        .dsList()
        .navigationTitle(MainTab.profile.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await permission.refresh() }
        .task(id: coordinator.session.user?.id) { await myTrips.load(forceReload: true) }
        .onChange(of: scenePhase) { _, phase in
            // The user may have changed it in Settings.
            if phase == .active {
                Task { await permission.refresh() }
            }
        }
        .sheet(isPresented: $showsPrePrompt) {
            NotificationsPrePromptView(
                onContinue: {
                    showsPrePrompt = false
                    Task { await permission.request() }
                },
                onNotNow: { showsPrePrompt = false }
            )
        }
    }

    @ViewBuilder private var accountRows: some View {
        switch coordinator.session {
        case let .signedIn(user):
            DSRow(
                user.name ?? String(localized: "Signed in"),
                subtitle: user.name == nil ? nil : String(localized: "Signed in"),
                systemImage: "person.circle"
            )
            Button(role: .destructive, action: signOut) {
                Text("Sign out")
            }
            .tint(theme.destructive)
            .disabled(isSigningOut)
        case .signedOut:
            DSRow("You're using the app as a guest", systemImage: "person.circle")
            Button("Sign in") { coordinator.requireAccount {} }
        }
    }

    /// The trips the person joined; each opens My trip.
    @ViewBuilder private var myEventsRows: some View {
        if let trips = myTrips.state.value, !trips.isEmpty {
            ForEach(trips) { trip in
                NavigationLink(value: EventsRoute.myTrip(trip.id)) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.event.name).textRole(.body)
                            Text(trip.placeAndDates)
                                .textRole(.subheadline)
                                .foregroundStyle(theme.labelSecondary)
                        }
                        Spacer(minLength: 8)
                        MyTripStatusTag(status: trip.status, compact: true)
                    }
                    .padding(.vertical, 6)
                }
            }
        } else if case .loaded = myTrips.state {
            Button("See open events") { coordinator.selectedTab = .events }
        } else {
            DSRow("Your trips show here", systemImage: "calendar")
        }
    }

    @ViewBuilder private var notificationRows: some View {
        switch permission.authorization {
        case .notDetermined:
            DSRow("Get updates as they happen", systemImage: "bell")
            Button("Turn on notifications") { showsPrePrompt = true }
        case .authorized:
            DSRow("Notifications are on", systemImage: "bell.badge")
        case .denied:
            DSRow(
                "Notifications are off",
                subtitle: String(localized: "You can turn them on in Settings."),
                systemImage: "bell.slash"
            )
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
        }
    }

    private func row(_ title: LocalizedStringKey, value: String) -> some View {
        LabeledContent {
            Text(verbatim: value).textRole(.body)
        } label: {
            Text(title).textRole(.body)
        }
    }

    private func signOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        Task {
            await coordinator.signOut()
            isSigningOut = false
        }
    }
}

#Preview {
    NavigationStack {
        let container = DependencyContainer.preview()
        MoreView(
            coordinator: AppCoordinator(container: container),
            myTrips: MyTripsViewModel(repository: container.myTrips, isSignedIn: { true })
        )
    }
    .theme(.system)
}
