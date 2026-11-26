import DataLayer
import DesignSystem
import SwiftUI

/// One joined trip: where you stand, what is left to do, where and when to
/// meet, and what is next. Opens from the saved copy when there is no signal.
struct MyTripView: View {
    @State private var viewModel: MyTripViewModel
    private let eventsAPI: EventsAPI
    private let imageLoader: any ImageLoading

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 14
    /// Pay was picked in the to-do sheet: push it once the sheet has gone,
    /// since a push made while a sheet is closing can be dropped.
    @State private var paysAfterSheet = false
    @State private var showsPay = false

    init(viewModel: MyTripViewModel, eventsAPI: EventsAPI, imageLoader: any ImageLoading) {
        _viewModel = State(initialValue: viewModel)
        self.eventsAPI = eventsAPI
        self.imageLoader = imageLoader
    }

    var body: some View {
        content
            .background(theme.background)
            .navigationTitle(viewModel.state.value?.event.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .dsToast($viewModel.toast)
            .task { await viewModel.load() }
            .onChange(of: isOnline) { _, isOnline in
                if isOnline {
                    Task { await viewModel.connectionRestored() }
                }
            }
            .sheet(isPresented: $viewModel.isShowingToDos, onDismiss: {
                if paysAfterSheet {
                    paysAfterSheet = false
                    showsPay = true
                }
            }, content: {
                if let trip = viewModel.state.value {
                    MyTripToDoSheet(trip: trip) {
                        paysAfterSheet = true
                        viewModel.isShowingToDos = false
                    }
                }
            })
            .navigationDestination(isPresented: $showsPay) {
                if let trip = viewModel.state.value {
                    MyTripPayLoader(
                        trip: trip,
                        eventsAPI: eventsAPI,
                        imageLoader: imageLoader,
                        onDone: {
                            showsPay = false
                            Task { await viewModel.load(forceReload: true) }
                        }
                    )
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            MyTripSkeleton()
        case let .loaded(trip):
            loaded(trip)
        case .failed:
            DSStateView.error(
                message: "Check your connection, then try again.",
                title: "Couldn't load your trip"
            ) {
                Task { await viewModel.load() }
            }
        case .offline:
            DSStateView.offline { Task { await viewModel.load() } }
        }
    }

    private func loaded(_ trip: MyTrip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(trip)
                if !trip.toDos.isEmpty {
                    toDoBanner(trip.toDos)
                }
                if let meetup = trip.meetup {
                    MyTripMeetCard(meetup: meetup, lead: trip.lead)
                }
                savedLine
                if let item = viewModel.upNext {
                    upNext(item)
                }
            }
            .screenMargins()
            .padding(.top, 8)
            .padding(.bottom, theme.spacing.groupGap)
        }
        .refreshable { await viewModel.load(forceReload: true) }
        .safeAreaInset(edge: .bottom) {
            if !isOnline {
                offlineNote
            }
        }
    }

    // MARK: - Pieces

    private func header(_ trip: MyTrip) -> some View {
        CDFlowLayout(spacing: 10) {
            statusPill(trip.status)
            if let countdown = viewModel.countdown {
                Text(countdown)
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
            }
        }
    }

    @ViewBuilder private func statusPill(_ status: MyTrip.Status) -> some View {
        if status == .going {
            Label { Text("You're going") } icon: { DSIcon(.check, role: .footnote) }
                .labelStyle(.titleAndIcon)
                .textRole(.footnote, emphasized: true)
                .foregroundStyle(theme.success)
                .padding(.leading, 8)
                .padding(.trailing, 10)
                .padding(.vertical, 4)
                .background(CDColor.successSoft, in: Capsule())
        } else {
            MyTripStatusTag(status: status)
        }
    }

    private func toDoBanner(_ toDos: [MyTrip.ToDo]) -> some View {
        Button { viewModel.isShowingToDos = true } label: {
            HStack(spacing: 10) {
                // At the largest sizes the words need the width more than the icon does.
                if !dynamicTypeSize.isAccessibilitySize {
                    DSIcon(.system("checklist"), role: .title3)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(Self.bannerTitle(count: toDos.count))
                        .textRole(.subheadline, emphasized: true)
                    Text(Self.bannerDetail(toDos))
                        .textRole(.footnote)
                }
                Spacer(minLength: 0)
                DSIcon(.chevronRight, role: .subheadline)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(CDColor.onHarvestSoft)
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .background(CDColor.harvestSoft, in: DesignSystem.Radius.shape(12))
            .contentShape(DesignSystem.Radius.shape(12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var savedLine: some View {
        Label {
            Text("Saved on this phone, so it opens with no signal")
        } icon: {
            DSIcon(.download, role: .footnote)
        }
        .textRole(.footnote)
        .foregroundStyle(theme.labelSecondary)
    }

    private func upNext(_ item: MyTrip.ScheduleItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Up next")
                .textRole(.title3, emphasized: true)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .strokeBorder(theme.accent, lineWidth: 2)
                    .frame(width: ringSize, height: ringSize)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(MyTrip.time.format(item.startsAt))
                        .textRole(.body, emphasized: true)
                    Text(item.title)
                        .textRole(.body)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.top, 4)
    }

    private var offlineNote: some View {
        Label {
            Text("You're offline. Your checklist and meeting point are saved on this phone.")
        } icon: {
            DSIcon(.system("wifi.slash"), role: .subheadline)
        }
        .textRole(.subheadline)
        .foregroundStyle(CDColor.onPine)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CDColor.pineGround, in: DesignSystem.Radius.shape(14))
        .screenMargins()
        .padding(.bottom, 8)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// "2 things to do before you go".
    static func bannerTitle(count: Int) -> String {
        count == 1
            ? String(localized: "1 thing to do before you go")
            : String(localized: "\(count) things to do before you go")
    }

    /// "Trip fee and guardian permit".
    static func bannerDetail(_ toDos: [MyTrip.ToDo]) -> String {
        let names = toDos.map(\.shortName)
        let text = ListFormatter.localizedString(byJoining: names)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

// MARK: - Previews

@MainActor
private func myTripPreview(
    _ id: Event.ID,
    _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
) -> some View {
    let container = DependencyContainer.preview(client: StubHTTPClient(handler))
    return NavigationStack {
        MyTripView(
            viewModel: MyTripViewModel(tripID: id, repository: container.myTrips),
            eventsAPI: container.eventsAPI,
            imageLoader: container.imageLoader
        )
    }
    .theme(.crossdrive)
}

#Preview("Going") { myTripPreview("behia-going", SampleStub.handle) }
#Preview("Pending") { myTripPreview("camp-feb", SampleStub.handle) }
#Preview("Waitlisted") { myTripPreview("bulan", SampleStub.handle) }
#Preview("Loading") {
    myTripPreview("behia-going") { _ in
        try await Task.sleep(for: .seconds(3600))
        return .json("[]")
    }
}

#Preview("Offline") { myTripPreview("behia-going") { _ in throw NetworkError.noConnection } }
