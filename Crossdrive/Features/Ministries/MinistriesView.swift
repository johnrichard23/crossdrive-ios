import DataLayer
import DesignSystem
import SwiftUI

/// Ministries: the ones CrossDrive runs, grouped by kind (Bible studies, the
/// school fund, skills programs), with a chip to show one kind.
struct MinistriesView: View {
    @State private var viewModel: MinistriesViewModel
    @Binding private var path: [MinistriesRoute]
    private let makeDetail: (Ministry.ID) -> MinistryDetailViewModel
    private let makeGive: (Ministry) -> GiveViewModel
    @State private var giving: GiveViewModel?

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        viewModel: MinistriesViewModel,
        path: Binding<[MinistriesRoute]>,
        makeDetail: @escaping (Ministry.ID) -> MinistryDetailViewModel,
        makeGive: @escaping (Ministry) -> GiveViewModel
    ) {
        _viewModel = State(initialValue: viewModel)
        _path = path
        self.makeDetail = makeDetail
        self.makeGive = makeGive
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
                    MinistryDetailView(viewModel: makeDetail(id), onGive: give)
                }
            }
        }
        .sheet(item: $giving) { model in
            GiveView(viewModel: model) { giving = nil }
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
        case .loaded:
            list
        case .failed:
            DSStateView.error(message: "Check your connection, then try again.") {
                Task { await viewModel.load() }
            }
        case .offline:
            DSStateView.offline { Task { await viewModel.load() } }
        }
    }

    private var skeleton: some View {
        ScrollView {
            MinistriesSkeleton()
                .padding(.bottom, theme.spacing.groupGap)
        }
        .scrollDisabled(true)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.kinds.count > 1 {
                    chips
                }
                ForEach(viewModel.sections) { section in
                    MinistrySectionView(section: section, onGive: give)
                }
            }
            .padding(.bottom, theme.spacing.groupGap)
        }
        .refreshable { await viewModel.load(forceReload: true) }
    }

    private func give(_ ministry: Ministry) {
        giving = makeGive(ministry)
    }

    /// All, then one chip per kind on the list.
    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(String(localized: "All"), isOn: viewModel.kind == nil) { viewModel.kind = nil }
                ForEach(viewModel.kinds, id: \.self) { kind in
                    chip(MinistrySection.title(of: kind), isOn: viewModel.kind == kind) {
                        viewModel.kind = kind
                    }
                }
            }
            .screenMargins()
        }
        .sensoryFeedback(.selection, trigger: viewModel.kind)
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .textRole(.subheadline, emphasized: isOn)
                .foregroundStyle(isOn ? theme.background : theme.labelPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(isOn ? theme.labelPrimary : theme.surface, in: Capsule())
                .overlay(Capsule().stroke(isOn ? .clear : theme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
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
                ministryID: id,
                imageLoader: URLSessionImageLoader()
            )
        },
        makeGive: { ministry in
            GiveViewModel(
                ministry: ministry,
                api: MinistriesAPI(client: StubHTTPClient(SampleStub.handle)),
                userName: { nil }
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
