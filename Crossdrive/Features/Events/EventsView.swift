import DataLayer
import DesignSystem
import SwiftUI

/// Events: upcoming trips and camps, with a kind filter.
struct EventsView: View {
    @State private var viewModel: EventsViewModel
    @State private var myTrips: MyTripsViewModel
    @Binding private var path: [EventsRoute]
    private let isSignedIn: Bool
    private let makeMyTrip: (Event.ID) -> MyTripView

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        viewModel: EventsViewModel,
        myTrips: MyTripsViewModel,
        isSignedIn: Bool,
        makeMyTrip: @escaping (Event.ID) -> MyTripView,
        path: Binding<[EventsRoute]>
    ) {
        _viewModel = State(initialValue: viewModel)
        _myTrips = State(initialValue: myTrips)
        self.isSignedIn = isSignedIn
        self.makeMyTrip = makeMyTrip
        _path = path
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Events")
                    .textRole(.largeTitle, emphasized: true)
                    .accessibilityAddTraits(.isHeader)
                    .screenMargins()
                    .padding(.top, 8)
                scopePicker.screenMargins()
                if viewModel.scope == .upcoming {
                    chips
                    content
                } else {
                    MyEventsList(
                        viewModel: myTrips,
                        onSeeOpenEvents: { viewModel.scope = .upcoming }
                    )
                    .task(id: isSignedIn) { await myTrips.load(forceReload: true) }
                }
            }
            .background(theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: EventsRoute.self) { route in
                switch route {
                case let .detail(id):
                    EventDetailView(
                        viewModel: viewModel.detailViewModel(for: id),
                        onOpenTrip: { path.append(.myTrip(id)) }
                    )
                case let .myTrip(id):
                    makeMyTrip(id)
                }
            }
        }
        .dsToast($viewModel.toast)
        .task { await viewModel.load() }
        .onChange(of: path) { _, routes in
            viewModel.openTripsChanged(to: routes.compactMap { route in
                if case let .detail(id) = route {
                    id
                } else {
                    nil
                }
            })
        }
        .onChange(of: isOnline) { _, isOnline in
            if isOnline {
                Task { await viewModel.connectionRestored() }
            }
        }
    }

    // MARK: - Controls

    /// A segmented control, or a menu at accessibility sizes.
    @ViewBuilder private var scopePicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Menu {
                Picker("Which events", selection: $viewModel.scope) {
                    ForEach(EventsViewModel.Scope.allCases, id: \.self) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.scope.title)
                    DSIcon(.system("chevron.down"), role: .subheadline)
                }
                .textRole(.body, emphasized: true)
                .foregroundStyle(theme.labelPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(theme.surfacePressed, in: Capsule())
            }
        } else {
            DSSegmentedControl(
                selection: $viewModel.scope,
                options: EventsViewModel.Scope.allCases,
                title: \.title
            )
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", isOn: viewModel.kind == nil) { viewModel.kind = nil }
                ForEach(EventKind.allCases, id: \.self) { kind in
                    chip(kind.chipLabel, isOn: viewModel.kind == kind) { viewModel.kind = kind }
                }
            }
            .screenMargins()
        }
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

    // MARK: - States

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            skeleton
        case let .loaded(events) where events.isEmpty:
            DSStateView(
                "No events yet.",
                message: "The next one will show here.",
                systemImage: "calendar"
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
        EventsSkeleton()
    }

    @ViewBuilder private var list: some View {
        if viewModel.visibleEvents.isEmpty {
            DSStateView(
                "Nothing here yet.",
                message: "No events of this kind right now.",
                systemImage: "calendar"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.visibleEvents) { event in
                        NavigationLink(value: EventsRoute.detail(event.id)) {
                            EventCard(event: event)
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
}

// MARK: - Previews: one per state

@MainActor
private func previewViewModel(
    _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
) -> EventsViewModel {
    EventsViewModel(
        api: EventsAPI(client: StubHTTPClient(handler)),
        imageLoader: URLSessionImageLoader(),
        snapshotter: AppleMapSnapshotter()
    )
}

@MainActor
private func previewScreen(_ viewModel: EventsViewModel) -> some View {
    EventsView(
        viewModel: viewModel,
        myTrips: MyTripsViewModel(
            repository: DependencyContainer.preview().myTrips,
            isSignedIn: { true }
        ),
        isSignedIn: true,
        makeMyTrip: { id in
            let container = DependencyContainer.preview()
            return MyTripView(
                viewModel: MyTripViewModel(tripID: id, repository: container.myTrips),
                eventsAPI: container.eventsAPI,
                imageLoader: container.imageLoader
            )
        },
        path: .constant([])
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
