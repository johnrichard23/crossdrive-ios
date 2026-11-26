import DataLayer
import DesignSystem
import SwiftUI

/// One trip: photo, the facts that help a guest decide, and a pinned bar. What
/// shows comes from the trip, so a mainland trip and an island trip use the
/// same screen. The order follows the questions a guest asks: where, why, what
/// it covers, what I would do, what to bring.
struct EventDetailView: View {
    @State private var viewModel: EventDetailViewModel
    private let source: EventDetailSource
    private let onOpenTrip: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accountGate) private var accountGate
    @Environment(\.isOnline) private var isOnline
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// The size the map is shown at; set by the map section once it is laid out.
    @State private var mapSize: CGSize = .zero
    /// The screen's width, known before anything is shown, so the photo and the
    /// map can be made ready at their real size while the skeleton is up.
    @State private var containerWidth: CGFloat = 0
    /// True once the photo has scrolled away, so the status bar gets a backing.
    @State private var showsStatusBackdrop = false
    /// The registration sheet, while it is up.
    @State private var registration: RegistrationViewModel?
    /// "Go to My trip" was tapped: open it once the sheet has gone, since a
    /// push made while a sheet is closing can be dropped.
    @State private var opensTripAfterSheet = false

    init(
        viewModel: EventDetailViewModel,
        source: EventDetailSource = .events,
        onOpenTrip: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.source = source
        self.onOpenTrip = onOpenTrip
    }

    var body: some View {
        content
            .background(theme.background)
            .overlay(alignment: .top) { statusBackdrop }
            .overlay(alignment: .top) { floatingButtons }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
            .task(id: containerWidth > 0) {
                guard containerWidth > 0 else { return }
                await viewModel.load(media: mediaLayout)
            }
            .task(id: MapRequest(
                size: mapSize,
                scale: displayScale,
                isDark: colorScheme == .dark
            )) {
                await viewModel.loadMap(
                    size: mapSize,
                    scale: displayScale,
                    isDark: colorScheme == .dark
                )
            }
            .onChange(of: isOnline) { _, isOnline in
                if isOnline {
                    Task { await viewModel.connectionRestored(media: mediaLayout) }
                }
            }
            .sheet(item: $registration, onDismiss: {
                if opensTripAfterSheet {
                    opensTripAfterSheet = false
                    onOpenTrip()
                }
            }, content: { model in
                RegistrationView(viewModel: model) { registered in
                    opensTripAfterSheet = registered
                    registration = nil
                    if registered {
                        Task { await viewModel.load(media: mediaLayout, forceReload: true) }
                    }
                }
            })
    }

    /// Register: a guest signs in first. The trip is read again before the
    /// steps open, so they start from the latest slots, and someone who turns
    /// out to have joined already (seen once signed in) is not asked twice.
    private func register(_ detail: EventDetail) {
        accountGate(for: detail.event.gateTrip) {
            Task {
                await viewModel.load(media: mediaLayout, forceReload: true)
                guard let fresh = viewModel.state.value,
                      fresh.bar == .register || fresh.bar == .full
                else { return }
                registration = viewModel.registrationViewModel(for: fresh)
            }
        }
    }

    private struct MapRequest: Equatable {
        var size: CGSize
        var scale: CGFloat
        var isDark: Bool
    }

    // MARK: - States

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            skeleton
        case let .loaded(detail):
            detailScreen(detail)
        case .failed where viewModel.isUnavailable:
            DSStateView(
                "This trip isn't available.",
                message: "It may be closed or taken down. See the trips that are open.",
                systemImage: "calendar",
                actionTitle: source.unavailableActionTitle,
                action: { dismiss() }
            )
        case .failed:
            DSStateView.error(message: "Check your connection, then try again.") {
                Task { await viewModel.load(media: mediaLayout) }
            }
        case .offline:
            DSStateView.offline { Task { await viewModel.load(media: mediaLayout) } }
        }
    }

    /// The shape of the loaded screen: photo, band, then a few cards.
    private var skeleton: some View {
        ScrollView {
            VStack(spacing: theme.spacing.groupGap) {
                Rectangle().fill(theme.surfacePressed).frame(height: heroHeight)
                VStack(spacing: theme.spacing.groupGap) {
                    ForEach(0 ..< 3, id: \.self) { _ in DSSkeletonCard() }
                }
                .screenMargins()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Loading"))
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    // MARK: - Floating buttons

    /// A frosted bar behind the clock, the battery and the back and share
    /// buttons once text scrolls under them, so the text never runs under a button.
    @ViewBuilder private var statusBackdrop: some View {
        if showsStatusBackdrop {
            GeometryReader { proxy in
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(theme.separator).frame(height: 1)
                    }
                    .frame(height: proxy.safeAreaInsets.top + buttonRowHeight)
                    .ignoresSafeArea(edges: .top)
            }
            .frame(height: 0)
            .transition(.opacity)
        }
    }

    /// The height of the back and share row: the 44 pt buttons grow with the text
    /// size, plus the padding above and below them.
    private var buttonRowHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 96 : 60
    }

    private var floatingButtons: some View {
        HStack {
            floatingButton(
                label: source.backLabel,
                action: { dismiss() },
                icon: { DSIcon(.chevronLeft, role: .body) }
            )
            Spacer()
            if let event = viewModel.state.value?.event {
                ShareLink(item: "\(event.title), \(event.dateRangeLabel)") {
                    floatingIcon { DSIcon(.share, role: .body) }
                }
                .accessibilityLabel(Text("Share this trip"))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func floatingButton(
        label: LocalizedStringKey,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> some View
    ) -> some View {
        Button(action: action) { floatingIcon(icon) }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(label))
    }

    private func floatingIcon(@ViewBuilder _ icon: () -> some View) -> some View {
        icon()
            .foregroundStyle(theme.labelPrimary)
            .padding(10)
            .frame(minWidth: 44, minHeight: 44)
            .background(theme.surface, in: Circle())
            .overlay(Circle().stroke(theme.border.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.16), radius: 3, y: 2)
    }

    // MARK: - Detail

    /// Space between sections: clearly more than the space inside one, so each
    /// section reads as its own group.
    private static let sectionGap: CGFloat = 40

    private var heroHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 620 : 340
    }

    /// Where the photo and the map will sit, from the screen width.
    private var mediaLayout: EventDetailViewModel.MediaLayout? {
        guard containerWidth > 0 else { return nil }
        let margin = theme.spacing.screenMargin(for: sizeClass)
        return EventDetailViewModel.MediaLayout(
            heroSize: CGSize(width: containerWidth, height: heroHeight),
            mapSize: CGSize(width: containerWidth - margin * 2, height: EventMapSection.height),
            scale: displayScale,
            isDark: colorScheme == .dark
        )
    }

    private func detailScreen(_ detail: EventDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScrollOffsetMarker()
                EventHero(event: detail.event, height: heroHeight, image: viewModel.heroImage)
                if !detail.bandStats.isEmpty {
                    EventBand(stats: detail.bandStats)
                }
                VStack(alignment: .leading, spacing: Self.sectionGap) {
                    sections(detail)
                    if dynamicTypeSize.isAccessibilitySize {
                        EventPinnedBar(
                            detail: detail,
                            onRegister: { register(detail) },
                            onOpenTrip: onOpenTrip
                        )
                        .padding(.horizontal, -theme.spacing.screenMarginCompact)
                    }
                }
                .screenMargins()
                .padding(.top, 32)
                .padding(.bottom, Self.sectionGap)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .statusBackdropOnScroll($showsStatusBackdrop, after: heroHeight - 80)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // At accessibility sizes the bar would fill the screen, so it scrolls with the page.
            if !dynamicTypeSize.isAccessibilitySize {
                EventPinnedBar(
                    detail: detail,
                    onRegister: { register(detail) },
                    onOpenTrip: onOpenTrip
                )
                .background(.regularMaterial)
                .overlay(alignment: .top) { Rectangle().fill(theme.separator).frame(height: 1) }
            }
        }
    }

    /// Guests decide from the place first; a person who is going prepares first.
    @ViewBuilder
    private func sections(_ detail: EventDetail) -> some View {
        if detail.isGoing {
            EventGoingCard(
                meetup: detail.meetup,
                day: detail.event.startDayLabel,
                waiverSigned: detail.registration?.waiverSigned ?? false,
                onOpenTrip: onOpenTrip
            )
            bring(detail)
            map(detail)
            covers(detail)
            why(detail)
            roles(detail)
        } else {
            map(detail)
            why(detail)
            covers(detail)
            roles(detail)
            bring(detail)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func map(_ detail: EventDetail) -> some View {
        if let location = detail.location {
            EventMapSection(location: location, image: viewModel.mapImage) { size in
                if size != mapSize {
                    mapSize = size
                }
            }
        }
    }

    @ViewBuilder
    private func why(_ detail: EventDetail) -> some View {
        if !detail.summary.isEmpty || !detail.background.isEmpty {
            EventWhySection(quote: detail.summary, background: detail.background)
        }
    }

    @ViewBuilder
    private func covers(_ detail: EventDetail) -> some View {
        if !detail.covers.isEmpty {
            EventCoversSection(
                title: detail.event.fee.map { "What \($0.formatted) covers" } ?? "What's included",
                covers: detail.covers,
                fitsGrid: detail.coversFitGrid,
                notCovered: detail.notCovered
            )
        }
    }

    @ViewBuilder
    private func roles(_ detail: EventDetail) -> some View {
        if !detail.roles.isEmpty {
            EventRolesSection(roles: detail.roles)
        }
    }

    @ViewBuilder
    private func bring(_ detail: EventDetail) -> some View {
        if !detail.bringList.isEmpty {
            EventBringSection(items: detail.bringList)
        }
    }
}

// MARK: - Previews: one per state

@MainActor
private func previewViewModel(
    id: String = "behia",
    _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse = SampleStub.handle
) -> EventDetailViewModel {
    EventDetailViewModel(
        api: EventsAPI(client: StubHTTPClient(handler)),
        eventID: id,
        imageLoader: URLSessionImageLoader(),
        snapshotter: AppleMapSnapshotter()
    )
}

#Preview("Guest") {
    EventDetailView(viewModel: previewViewModel()).theme(.crossdrive)
}

#Preview("Going") {
    EventDetailView(viewModel: previewViewModel(id: "behia-going")).theme(.crossdrive)
}

#Preview("Full") {
    EventDetailView(viewModel: previewViewModel(id: "behia-full")).theme(.crossdrive)
}

#Preview("Mainland") {
    EventDetailView(viewModel: previewViewModel(id: "bulan")).theme(.crossdrive)
}

#Preview("Loading") {
    EventDetailView(
        viewModel: previewViewModel { _ in
            try await Task.sleep(for: .seconds(3600))
            return .json("{}")
        }
    )
    .theme(.crossdrive)
}

#Preview("Not available") {
    EventDetailView(viewModel: previewViewModel { _ in .json("{}", status: 404) })
        .theme(.crossdrive)
}

#Preview("Error") {
    EventDetailView(viewModel: previewViewModel { _ in .json("{}", status: 500) })
        .theme(.crossdrive)
}

#Preview("Offline") {
    EventDetailView(viewModel: previewViewModel { _ in throw NetworkError.noConnection })
        .theme(.crossdrive)
}

// MARK: - Status bar backing

private extension View {
    /// Turns `flag` on once the scroll offset passes `offset`. iOS 18 reads the
    /// offset from the scroll view itself. iOS 17 reads it from a marker at the
    /// top of the content (`ScrollOffsetMarker`), and only sets the flag when it
    /// crosses the line, not on every frame.
    @ViewBuilder
    func statusBackdropOnScroll(_ flag: Binding<Bool>, after offset: CGFloat) -> some View {
        if #available(iOS 18, *) {
            onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > offset
            } action: { _, isPast in
                withAnimation(DesignSystem.Motion.enter) { flag.wrappedValue = isPast }
            }
        } else {
            coordinateSpace(name: ScrollOffsetMarker.space)
                .onPreferenceChange(ScrollOffsetMarker.Key.self) { scrolled in
                    let isPast = scrolled > offset
                    if flag.wrappedValue != isPast {
                        flag.wrappedValue = isPast
                    }
                }
        }
    }
}

/// A zero-height marker at the top of the scroll content that reports how far
/// the page has scrolled. Needed only before iOS 18.
private struct ScrollOffsetMarker: View {
    static let space = "tripScroll"

    struct Key: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    var body: some View {
        if #available(iOS 18, *) {
            EmptyView()
        } else {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: Key.self,
                    value: -proxy.frame(in: .named(Self.space)).minY
                )
            }
            .frame(height: 0)
        }
    }
}

/// Where a trip was opened from, so its back control and its "not available"
/// action name the place they return to.
enum EventDetailSource {
    case events
    case home

    var backLabel: LocalizedStringKey {
        switch self {
        case .events: "Back to Events"
        case .home: "Back to Home"
        }
    }

    var unavailableActionTitle: String {
        switch self {
        case .events: "See events"
        case .home: "Go back"
        }
    }
}
