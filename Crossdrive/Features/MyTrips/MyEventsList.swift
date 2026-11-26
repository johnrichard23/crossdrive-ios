import DesignSystem
import SwiftUI

/// Events › My events: the trips the person joined, soonest first.
struct MyEventsList: View {
    @Bindable var viewModel: MyTripsViewModel
    let onSeeOpenEvents: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline
    @Environment(\.accountGate) private var accountGate

    var body: some View {
        content
            .dsToast($viewModel.toast)
            .onChange(of: isOnline) { _, isOnline in
                if isOnline {
                    Task { await viewModel.connectionRestored() }
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            EventsSkeleton()
        case let .loaded(trips) where trips.isEmpty:
            empty
        case let .loaded(trips):
            list(trips)
        case .failed:
            DSStateView.error(
                message: "Check your connection, then try again.",
                title: "Couldn't load your trips"
            ) {
                Task { await viewModel.load(forceReload: true) }
            }
        case .offline:
            DSStateView.offline { Task { await viewModel.load(forceReload: true) } }
        }
    }

    /// A guest is offered the sign-in that brings their trips back.
    private var empty: some View {
        DSStateView(
            "You haven't joined a trip yet.",
            message: "Register for one and your checklist and meeting point show here.",
            actionTitle: "See open events",
            action: onSeeOpenEvents,
            secondaryActionTitle: viewModel.isGuest ? "Sign in" : nil,
            secondaryAction: viewModel.isGuest ? { accountGate {} } : nil
        )
    }

    private func list(_ trips: [MyTrip]) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(trips) { trip in
                    NavigationLink(value: EventsRoute.myTrip(trip.id)) {
                        MyTripCard(trip: trip)
                    }
                    .buttonStyle(.plain)
                }
            }
            .screenMargins()
            .padding(.bottom, theme.spacing.groupGap)
        }
        .refreshable { await viewModel.load(forceReload: true) }
    }
}
