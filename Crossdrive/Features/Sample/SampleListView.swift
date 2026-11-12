import DataLayer
import DesignSystem
import SwiftUI

/// The reference screen: a list with all four states (loading, empty, error,
/// offline), pull to refresh, and a push to a detail screen.
struct SampleListView: View {
    @State private var viewModel: SampleListViewModel
    @Binding private var path: [SampleRoute]

    @Environment(\.theme) private var theme
    @Environment(\.accountGate) private var accountGate
    @Environment(\.isOnline) private var isOnline
    @Environment(\.featureFlags) private var flags

    init(viewModel: SampleListViewModel, path: Binding<[SampleRoute]>) {
        _viewModel = State(initialValue: viewModel)
        _path = path
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(theme.background)
                .navigationTitle("Items")
                .navigationDestination(for: SampleRoute.self) { route in
                    switch route {
                    case let .detail(id):
                        SampleDetailView(viewModel: viewModel, itemID: id)
                    }
                }
        }
        .dsToast($viewModel.toast)
        .task { await viewModel.load() }
        .onChange(of: isOnline) { _, isOnline in
            if isOnline {
                Task { await viewModel.connectionRestored() }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            skeleton
        case let .loaded(items) where items.isEmpty:
            DSStateView(
                "No items yet",
                message: "Items you add appear here.",
                systemImage: "tray",
                actionTitle: "Refresh",
                action: { Task { await viewModel.load(forceReload: true) } }
            )
        case let .loaded(items):
            list(items)
        case let .failed(message):
            DSStateView.error(message: message) { Task { await viewModel.load() } }
        case .offline:
            DSStateView.offline { Task { await viewModel.load() } }
        }
    }

    private var skeleton: some View {
        ScrollView {
            VStack(spacing: theme.spacing.groupGap) {
                ForEach(0 ..< 4, id: \.self) { _ in DSSkeletonCard() }
            }
            .screenMargins()
            .padding(.vertical, theme.spacing.groupGap)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Loading"))
        }
    }

    private func list(_ items: [Item]) -> some View {
        List {
            Section {
                ForEach(items) { item in
                    NavigationLink(value: SampleRoute.detail(item.id)) {
                        DSRow(
                            item.title,
                            subtitle: item.summary,
                            systemImage: item.isFavorite ? "heart.fill" : "heart"
                        )
                        .accessibilityValue(item.isFavorite ? Text("Favorite") : Text(verbatim: ""))
                    }
                    .swipeActions {
                        if flags.isEnabled(.favorites) {
                            Button {
                                accountGate { Task { await viewModel.toggleFavorite(item.id) } }
                            } label: {
                                Text(SampleFavoriteTitle.text(isFavorite: item.isFavorite))
                            }
                            .tint(theme.accent)
                        }
                    }
                }
            }
            .dsListRows()
        }
        .dsList()
        .refreshable { await viewModel.load(forceReload: true) }
    }
}

/// The favourite button's words, shared by the list and the detail screen.
enum SampleFavoriteTitle {
    static func text(isFavorite: Bool) -> LocalizedStringKey {
        isFavorite ? "Remove favorite" : "Add favorite"
    }
}

// MARK: - Previews: one per state

@MainActor
private func previewViewModel(
    _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
) -> SampleListViewModel {
    SampleListViewModel(api: SampleAPI(client: StubHTTPClient(handler)))
}

#Preview("Loaded") {
    SampleListView(viewModel: previewViewModel(SampleStub.handle), path: .constant([]))
        .theme(.system)
}

#Preview("Loading") {
    SampleListView(
        viewModel: previewViewModel { _ in
            try await Task.sleep(for: .seconds(3600))
            return .json("[]")
        },
        path: .constant([])
    )
    .theme(.system)
}

#Preview("Empty") {
    SampleListView(viewModel: previewViewModel { _ in .json("[]") }, path: .constant([]))
        .theme(.system)
}

#Preview("Error") {
    SampleListView(
        viewModel: previewViewModel { _ in .json("{}", status: 500) },
        path: .constant([])
    )
    .theme(.system)
}

#Preview("Offline") {
    SampleListView(
        viewModel: previewViewModel { _ in throw NetworkError.noConnection },
        path: .constant([])
    )
    .theme(.system)
}
