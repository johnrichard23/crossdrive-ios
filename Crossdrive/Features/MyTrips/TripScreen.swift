import SwiftUI

/// My trip, or a schedule screen under it, in a tab's stack.
struct TripScreen: View {
    let route: EventsRoute
    let models: MainTabModels

    var body: some View {
        switch route {
        case let .myTrip(id):
            models.myTripView(id)
        case let .schedule(id), let .activity(id, _):
            ScheduleScreen(route: route, viewModel: models.schedule(id))
        case .detail:
            // Trip detail is built by each stack, which knows where its Register leads.
            EmptyView()
        }
    }
}

/// The schedule, or one activity on it, for a stack that already has the
/// trip's schedule view model.
struct ScheduleScreen: View {
    let route: EventsRoute
    let viewModel: ScheduleViewModel

    var body: some View {
        switch route {
        case let .activity(_, itemID):
            ScheduleItemView(viewModel: viewModel, itemID: itemID)
        case .schedule:
            ScheduleView(viewModel: viewModel)
        case .detail, .myTrip:
            EmptyView()
        }
    }
}
