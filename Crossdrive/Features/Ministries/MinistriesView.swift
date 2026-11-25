import DataLayer
import DesignSystem
import SwiftUI

/// Ministries: the ones CrossDrive runs, each with Pray and Give.
struct MinistriesView: View {
    @State private var viewModel: MinistriesViewModel
    @Binding private var path: [MinistriesRoute]
    private let makeDetail: (Ministry.ID) -> MinistryDetailViewModel

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        viewModel: MinistriesViewModel,
        path: Binding<[MinistriesRoute]>,
        makeDetail: @escaping (Ministry.ID) -> MinistryDetailViewModel
    ) {
        _viewModel = State(initialValue: viewModel)
        _path = path
        self.makeDetail = makeDetail
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Ministries")
                    .textRole(.largeTitle, emphasized: true)
                    .accessibilityAddTraits(.isHeader)
                    .screenMargins()
                    .padding(.top, 8)
                content
            }
            .background(theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MinistriesRoute.self) { route in
                switch route {
                case let .detail(id):
                    MinistryDetailView(viewModel: makeDetail(id))
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
        case let .loaded(ministries) where ministries.isEmpty:
            DSStateView(
                "No ministries yet.",
                message: "Our ministries will show here.",
                systemImage: "person.2"
            )
        case let .loaded(ministries):
            list(ministries)
        case .failed:
            DSStateView.error(message: "Check your connection, then try again.") {
                Task { await viewModel.load() }
            }
        case .offline:
            DSStateView.offline { Task { await viewModel.load() } }
        }
    }

    /// The give banner is real and stays; only the cards wait for their data.
    private var skeleton: some View {
        ScrollView {
            VStack(spacing: 16) {
                giveBanner
                MinistriesSkeleton()
            }
            .screenMargins()
            .padding(.bottom, theme.spacing.groupGap)
        }
        .scrollDisabled(true)
    }

    private func list(_ ministries: [Ministry]) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                giveBanner
                ForEach(ministries) { ministry in
                    MinistryCard(ministry: ministry)
                }
            }
            .screenMargins()
            .padding(.bottom, theme.spacing.groupGap)
        }
        .refreshable { await viewModel.load(forceReload: true) }
    }

    /// The general Give page, for gifts that go where the need is greatest.
    private var giveBanner: some View {
        Button {} label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Give where it's needed most")
                        .textRole(.headline, emphasized: true)
                        .foregroundStyle(CDColor.onPine)
                    Text("The team uses it where the need is greatest.")
                        .textRole(.subheadline)
                        .foregroundStyle(CDColor.onPineMuted)
                }
                Spacer(minLength: 0)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CDColor.pineGround, in: DesignSystem.Radius.shape(16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews: one per state

@MainActor
private func previewViewModel(
    _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
) -> MinistriesViewModel {
    MinistriesViewModel(api: MinistriesAPI(client: StubHTTPClient(handler)))
}

@MainActor
private func previewScreen(_ viewModel: MinistriesViewModel) -> some View {
    MinistriesView(
        viewModel: viewModel,
        path: .constant([]),
        makeDetail: { id in
            MinistryDetailViewModel(
                api: MinistriesAPI(client: StubHTTPClient(SampleStub.handle)),
                ministryID: id
            )
        }
    )
    .theme(.crossdrive)
}

#Preview("Loaded") {
    previewScreen(previewViewModel(SampleStub.handle))
}

#Preview("Loading") {
    previewScreen(
        previewViewModel { _ in
            try await Task.sleep(for: .seconds(3600))
            return .json("[]")
        }
    )
}

#Preview("Empty") {
    previewScreen(previewViewModel { _ in .json("[]") })
}

#Preview("Error") {
    previewScreen(previewViewModel { _ in .json("{}", status: 500) })
}

#Preview("Offline") {
    previewScreen(previewViewModel { _ in throw NetworkError.noConnection })
}
