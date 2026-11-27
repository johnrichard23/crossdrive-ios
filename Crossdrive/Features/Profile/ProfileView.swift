import DataLayer
import DesignSystem
import SwiftUI

/// Profile: who you are, the trips you joined, settings, and signing out. A
/// guest sees why to sign in, with the settings that need no account.
struct ProfileView: View {
    let coordinator: AppCoordinator
    let myTrips: MyTripsViewModel
    /// Opens Events › My events, for when there are more trips than the row shows.
    let onSeeAllTrips: () -> Void

    @State private var isSigningOut = false

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 72

    private var container: DependencyContainer {
        coordinator.container
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch coordinator.session {
                case let .signedIn(user):
                    signedIn(user)
                case .signedOut:
                    guest
                }
                #if DEBUG || STAGING
                    developer
                #endif
            }
            .screenMargins()
            .padding(.top, 8)
            .padding(.bottom, theme.spacing.groupGap)
        }
        .background(theme.background)
        .navigationTitle(MainTab.profile.title)
        .navigationBarTitleDisplayMode(.large)
        .task(id: coordinator.session.user?.id) { await myTrips.load(forceReload: true) }
        .navigationDestination(for: ProfileRoute.self) { route in
            switch route {
            case .notifications:
                NotificationSettingsView(push: container.services.push)
            #if DEBUG || STAGING
                case .debugMenu:
                    DebugMenuView(coordinator: coordinator)
            #endif
            }
        }
    }

    // MARK: - Signed in

    @ViewBuilder private func signedIn(_ user: AppUser) -> some View {
        let summary = ProfileSummary(user: user, trips: myTrips.state.value ?? [], now: .now)
        card(summary)
        trips(summary)
        settings
        group {
            Button(action: signOut) {
                row(title: "Sign out")
            }
            .buttonStyle(.plain)
            .disabled(isSigningOut)
        }
    }

    private func card(_ summary: ProfileSummary) -> some View {
        VStack(spacing: 0) {
            avatar(summary.initials)
            Text(summary.name)
                .textRole(.title2, emphasized: true)
                .foregroundStyle(theme.labelPrimary)
                .padding(.top, 12)
            if myTrips.state.value != nil {
                Text(summary.tripsLine)
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
                    .padding(.top, 2)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .background(theme.surface, in: DesignSystem.Radius.shape(20))
        .accessibilityElement(children: .combine)
    }

    private func avatar(_ initials: String) -> some View {
        ZStack {
            Circle().fill(CDColor.brandSoft)
            if initials.isEmpty {
                DSIcon(.user, role: .title1)
            } else {
                Text(initials).textRole(.title1, emphasized: true)
            }
        }
        .foregroundStyle(CDColor.onBrandSoft)
        .frame(width: avatarSize, height: avatarSize)
        .accessibilityHidden(true)
    }

    private func trips(_ summary: ProfileSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your trips")
                    .textRole(.footnote, emphasized: true)
                    .foregroundStyle(theme.labelSecondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if summary.hasMoreTrips {
                    Button("See all", action: onSeeAllTrips)
                        .textRole(.subheadline, emphasized: true)
                        .foregroundStyle(theme.accent)
                        .frame(minHeight: DesignSystem.minTapTarget)
                        .padding(.vertical, -12)
                }
            }
            .padding(.leading, 14)
            tripsContent(summary)
        }
    }

    @ViewBuilder private func tripsContent(_ summary: ProfileSummary) -> some View {
        switch myTrips.state {
        case .loading:
            ProfileTripsSkeleton()
        case let .loaded(trips) where trips.isEmpty:
            group {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your trips show here once you register for one.")
                        .textRole(.body)
                        .foregroundStyle(theme.labelSecondary)
                    Button("See open events") { coordinator.selectedTab = .events }
                        .textRole(.body, emphasized: true)
                        .foregroundStyle(theme.accent)
                        .frame(minHeight: DesignSystem.minTapTarget)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .loaded:
            ProfileTripsRow(trips: summary.trips)
        case .failed, .offline:
            group {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Couldn't load your trips.")
                        .textRole(.body)
                        .foregroundStyle(theme.labelSecondary)
                    Button("Try again") { Task { await myTrips.load(forceReload: true) } }
                        .textRole(.body, emphasized: true)
                        .foregroundStyle(theme.accent)
                        .frame(minHeight: DesignSystem.minTapTarget)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Guest

    @ViewBuilder private var guest: some View {
        if container.features.authentication == .optional {
            guestSignIn
        }
        settings
    }

    private var guestSignIn: some View {
        VStack(spacing: 10) {
            Text("You're browsing as a guest.")
                .textRole(.title2, emphasized: true)
                .foregroundStyle(theme.labelPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Sign in to register for trips and keep your trip details on this phone.")
                .textRole(.body)
                .foregroundStyle(theme.labelSecondary)
            Button("Sign in") { coordinator.requireAccount {} }
                .buttonStyle(.ds(.outline, size: .regular, expandsWidth: false))
                .padding(.top, 14)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
    }

    // MARK: - Settings

    private var settings: some View {
        group {
            NavigationLink(value: ProfileRoute.notifications) {
                row(icon: .bell, title: "Notifications", trailing: .chevronRight)
            }
            .buttonStyle(.plain)
            if let url = TripLinks.messenger {
                Divider().overlay(theme.surfacePressed).padding(.leading, 46)
                Button { openURL(url) } label: {
                    row(
                        icon: .message,
                        title: "Message CrossDrive",
                        trailing: .system("arrow.up.right")
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Messenger")
            }
        }
    }

    #if DEBUG || STAGING
        private var developer: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text("This build: \(container.environment.kind.rawValue.capitalized)")
                    .textRole(.footnote)
                    .foregroundStyle(theme.labelSecondary)
                    .padding(.leading, 14)
                group {
                    NavigationLink(value: ProfileRoute.debugMenu) {
                        row(title: "Debug menu", trailing: .chevronRight)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    #endif

    // MARK: - Pieces

    /// A white rounded group of rows.
    private func group(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 0, content: content)
            .background(theme.surface, in: DesignSystem.Radius.shape(20))
    }

    private func row(
        icon: DSIcon.Source? = nil,
        title: LocalizedStringKey,
        trailing: DSIcon.Source? = nil
    ) -> some View {
        HStack(spacing: 12) {
            if let icon {
                DSIcon(icon, role: .body)
                    .foregroundStyle(theme.labelSecondary)
                    .accessibilityHidden(true)
            }
            Text(title)
                .textRole(.body)
                .foregroundStyle(theme.labelPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                DSIcon(trailing, role: .subheadline)
                    .foregroundStyle(theme.labelTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
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

/// Where the Profile stack can go, besides a trip.
enum ProfileRoute: Hashable {
    case notifications
    #if DEBUG || STAGING
        case debugMenu
    #endif
}

// MARK: - Previews

@MainActor
private func profilePreview(signedIn: Bool) -> some View {
    let container = DependencyContainer.preview()
    let coordinator = AppCoordinator(container: container)
    return NavigationStack {
        ProfileView(
            coordinator: coordinator,
            myTrips: MyTripsViewModel(repository: container.myTrips, isSignedIn: { signedIn }),
            onSeeAllTrips: {}
        )
    }
    .theme(.crossdrive)
}

#Preview("Guest") { profilePreview(signedIn: false) }
