import SwiftUI

/// My trip in a sheet: where a reminder notification lands, over whatever
/// screen was open, so the person keeps their place.
struct MyTripSheet: View {
    private let container: DependencyContainer

    @State private var viewModel: MyTripViewModel
    @Environment(\.dismiss) private var dismiss

    init(tripID: Event.ID, container: DependencyContainer) {
        self.container = container
        _viewModel = State(initialValue: MyTripViewModel(tripID: tripID, container: container))
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
