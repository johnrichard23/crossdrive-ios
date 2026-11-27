import DesignSystem
import SwiftUI
import UIKit

/// Profile › Notifications: whether notifications are on, with a way to turn
/// them on here or in Settings.
struct NotificationSettingsView: View {
    @State private var permission: NotificationPermissionViewModel
    @State private var showsPrePrompt = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    init(push: any PushRegistrar) {
        _permission = State(initialValue: NotificationPermissionViewModel(push: push))
    }

    var body: some View {
        List {
            Section {
                rows
            }
            .dsListRows()
        }
        .dsList()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await permission.refresh() }
        .onChange(of: scenePhase) { _, phase in
            // The person may have changed it in Settings.
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

    @ViewBuilder private var rows: some View {
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
}

#Preview {
    NavigationStack {
        NotificationSettingsView(push: DependencyContainer.preview().services.push)
    }
    .theme(.crossdrive)
}
