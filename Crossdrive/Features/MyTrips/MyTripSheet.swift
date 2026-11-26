import SwiftUI

/// My trip in a sheet: where a reminder notification lands, over whatever
/// screen was open, so the person keeps their place.
struct MyTripSheet: View {
    private let container: DependencyContainer

    @State private var viewModel: MyTripViewModel
    @State private var schedule: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    init(tripID: Event.ID, container: DependencyContainer) {
        self.container = container
        _viewModel = State(initialValue: MyTripViewModel(tripID: tripID, container: container))
        _schedule = State(initialValue: ScheduleViewModel(
            tripID: tripID,
            repository: container.myTrips,
            store: container.myTripsStore
        ))
    }

    var body: some View {
        NavigationStack {
            MyTripView(
                viewModel: viewModel,
                eventsAPI: container.eventsAPI,
                imageLoader: container.imageLoader
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: EventsRoute.self) { route in
                ScheduleScreen(route: route, viewModel: schedule)
            }
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            MyTripSheet(tripID: "behia-going", container: .preview())
        }
        .theme(.crossdrive)
}
