import DataLayer
import DesignSystem
import SwiftUI

/// Home: the next trip as a ticket, then the latest mission story.
struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var film: HomeStory?
    /// The screen's width, known before anything shows, so the photos can be
    /// made ready at their real size while the skeleton is up.
    @State private var containerWidth: CGFloat = 0
    @Binding private var path: [EventsRoute]

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline
    @Environment(\.displayScale) private var displayScale
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accountGate) private var accountGate

    init(viewModel: HomeViewModel, path: Binding<[EventsRoute]>) {
        _viewModel = State(initialValue: viewModel)
        _path = path
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header
                content
            }
            .background(theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: EventsRoute.self) { route in
                switch route {
                case let .detail(id):
                    EventDetailView(viewModel: viewModel.detailViewModel(for: id))
                }
            }
        }
        .dsToast($viewModel.toast)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        .task(id: containerWidth > 0) {
            guard containerWidth > 0 else { return }
            await viewModel.load(media: mediaLayout)
        }
        .onChange(of: isOnline) { _, isOnline in
            if isOnline {
                Task { await viewModel.connectionRestored(media: mediaLayout) }
            }
        }
        .onChange(of: path) { _, routes in
            viewModel.openTripsChanged(to: routes.map { route in
                switch route {
                case let .detail(id): id
                }
            })
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.refreshCountdown()
            }
        }
        .sheet(item: $film) { story in
            if let url = story.filmURL {
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }

    // MARK: - Layout

    private var contentWidth: CGFloat {
        max(containerWidth - 2 * theme.spacing.screenMargin(for: sizeClass), 0)
    }

    private var storyHeight: CGFloat {
        300
    }

    private var mediaLayout: HomeViewModel.MediaLayout {
        HomeViewModel.MediaLayout(
            tripSize: CGSize(width: 130, height: 130),
            storySize: CGSize(width: contentWidth, height: storyHeight),
            scale: displayScale
        )
    }

    private var header: some View {
        HStack {
            Image("Logo/Lockup")
                .resizable()
                .scaledToFit()
                .frame(height: 32)
                .frame(minHeight: DesignSystem.minTapTarget)
                .accessibilityLabel(Text("CrossDrive Missions"))
            Spacer()
        }
        .screenMargins()
        .padding(.top, 8)
    }

    // MARK: - States

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            skeleton
        case let .loaded(summary):
            feed(summary)
        case .failed:
            DSStateView.error(message: "Check your connection, then try again.") {
                Task { await viewModel.load(media: mediaLayout) }
            }
        case .offline:
            DSStateView.offline { Task { await viewModel.load(media: mediaLayout) } }
        }
    }

    private var skeleton: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Next event").textRole(.title3, emphasized: true).hidden()
                DSSkeletonCard()
                DSSkeletonCard()
            }
            .screenMargins()
            .padding(.top, 12)
            .padding(.bottom, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Loading"))
        }
    }

    private func feed(_ summary: HomeSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                tripSection(summary.trip)
                if let story = summary.latestStory {
                    HomeStories(
                        story: story,
                        photo: viewModel.storyImage,
                        height: storyHeight
                    ) { film = story }
                }
            }
            .screenMargins()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .refreshable { await viewModel.load(media: mediaLayout, forceReload: true) }
    }

    private func tripSection(_ trip: HomeTrip?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let trip {
                Text(trip.isGoing ? "Your event" : "Next event")
                    .textRole(.title3, emphasized: true)
                    .accessibilityAddTraits(.isHeader)
                HomeTicket(
                    trip: trip,
                    countdown: viewModel.countdown,
                    photo: viewModel.tripImage,
                    onRegister: { accountGate {} },
                    onOpenTrip: { path.append(.detail(trip.event.id)) }
                )
            } else {
                HomeNoTripCard()
            }
        }
    }
}
