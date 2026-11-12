import DesignSystem
import SwiftUI
import UIKit

/// Account, notifications and build information. A project replaces the build
/// section with its own settings.
struct MoreView: View {
    let coordinator: AppCoordinator

    @State private var permission: NotificationPermissionViewModel
    @State private var showsPrePrompt = false
    @State private var isSigningOut = false

    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
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
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
        .task { await permission.refresh() }
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
        MoreView(coordinator: AppCoordinator(container: .preview()))
    }
    .theme(.system)
}
