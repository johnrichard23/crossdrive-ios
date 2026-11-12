import DesignSystem
import SwiftUI

/// Pushed from the list, or shown alone in a sheet. It reads the item from
/// the view model, so a change made here or in the list shows in both, and it
/// has the same four states as the list.
struct SampleDetailView: View {
    let viewModel: SampleListViewModel
    let itemID: Item.ID

    @Environment(\.theme) private var theme
    @Environment(\.accountGate) private var accountGate
    @Environment(\.featureFlags) private var flags

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text("Loading"))
            case let .failed(message):
                DSStateView.error(message: message) { Task { await viewModel.load() } }
            case .offline:
                DSStateView.offline { Task { await viewModel.load() } }
            case .loaded:
                if let item = viewModel.item(withID: itemID) {
                    content(item)
                } else {
                    DSStateView(
                        "Item not found",
                        message: "It may have been removed.",
                        systemImage: "questionmark.folder"
                    )
                }
            }
        }
        .background(theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(_ item: Item) -> some View {
        let details = ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(item.title)
                    .textRole(.title1, emphasized: true)
                Text(item.summary)
                    .textRole(.body)
                    .foregroundStyle(theme.labelSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .screenMargins()
            .padding(.vertical, theme.spacing.groupGap)
        }

        if flags.isEnabled(.favorites) {
            details.dsBottomBar {
                Button {
                    accountGate { Task { await viewModel.toggleFavorite(item.id) } }
                } label: {
                    Text(SampleFavoriteTitle.text(isFavorite: item.isFavorite))
                }
                .buttonStyle(
                    .ds(.primary, isLoading: viewModel.favoritesInFlight.contains(item.id))
                )
            }
        } else {
            details
        }
    }
}
