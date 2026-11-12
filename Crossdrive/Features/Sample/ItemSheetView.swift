import SwiftUI

/// One item in a sheet: where a notification tap lands. It loads for itself,
/// so it works from any screen and at any point in the app's life.
struct ItemSheetView: View {
    let itemID: Item.ID

    @State private var viewModel: SampleListViewModel
    @Environment(\.dismiss) private var dismiss

    init(itemID: Item.ID, container: DependencyContainer) {
        self.itemID = itemID
        _viewModel = State(
            initialValue: SampleListViewModel(
                api: container.sampleAPI,
                reporter: container.services.crashReporter
            )
        )
    }

    var body: some View {
        NavigationStack {
            SampleDetailView(viewModel: viewModel, itemID: itemID)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .task { await viewModel.load() }
    }
}
