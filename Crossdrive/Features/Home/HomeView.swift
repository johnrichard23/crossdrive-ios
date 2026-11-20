import DataLayer
import DesignSystem
import SwiftUI

/// Home: the next event, today's prayer point and the latest story.
struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var hasPrayed = false
    private let onOpenEvent: (Event.ID) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(viewModel: HomeViewModel, onOpenEvent: @escaping (Event.ID) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onOpenEvent = onOpenEvent
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                content
            }
            .background(theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .dsToast($viewModel.toast)
        .task { await viewModel.load() }
        .onChange(of: isOnline) { _, isOnline in
            if isOnline {
                Task { await viewModel.connectionRestored() }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image("Logo/Lockup")
                .resizable()
                .scaledToFit()
                .frame(height: 32)
                .frame(minHeight: DesignSystem.minTapTarget)
                .accessibilityLabel(Text("CrossDrive Missions"))
            Spacer()
            Button {} label: {
                DSIcon(.bell, role: .body)
                    .padding(10)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(theme.surface, in: Circle())
                    .overlay(Circle().stroke(theme.separator, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Notifications"))
        }
        .screenMargins()
        .padding(.top, 8)
    }

    // MARK: - States

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            skeleton
        case let .loaded(summary) where summary.isEmpty:
            DSStateView(
                "No trip planned yet.",
                message: "When the team sets the dates, the next trip shows up here.",
                systemImage: "house",
                actionTitle: "Refresh",
                action: { Task { await viewModel.load(forceReload: true) } }
            )
        case let .loaded(summary):
            feed(summary)
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
            VStack(spacing: theme.spacing.groupGap) {
                ForEach(0 ..< 3, id: \.self) { _ in DSSkeletonCard() }
            }
            .screenMargins()
            .padding(.vertical, theme.spacing.groupGap)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Loading"))
        }
    }

    private func feed(_ summary: HomeSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let event = summary.nextEvent {
                    Text("Next trip")
                        .textRole(.title3, emphasized: true)
                        .accessibilityAddTraits(.isHeader)
                    eventCard(event)
                }
                if let prayer = summary.prayerPoint {
                    prayerCard(prayer)
                }
                if let story = summary.latestStory {
                    VStack(alignment: .leading, spacing: 10) {
                        CDLanes(color: theme.accent)
                        Text("From the last trip")
                            .textRole(.title3, emphasized: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    .padding(.top, 8)
                    storyCard(story)
                }
            }
            .screenMargins()
            .padding(.top, 14)
            .padding(.bottom, theme.spacing.groupGap)
        }
        .refreshable { await viewModel.load(forceReload: true) }
    }

    // MARK: - Next trip

    private func eventCard(_ event: Event) -> some View {
        Button { onOpenEvent(event.id) } label: {
            VStack(alignment: .leading, spacing: 0) {
                DSRemoteImage(url: event.heroImageURL) { DSImagePlaceholder() }
                    .frame(height: 150)
                    .accessibilityHidden(true)
                eventDetails(event)
                DashedRule(color: theme.separator)
                    .padding(.horizontal, 16)
                eventFooter(event)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(DesignSystem.Radius.shape(theme.radius.card))
            .overlay(
                DesignSystem.Radius.shape(theme.radius.card).stroke(theme.separator, lineWidth: 1)
            )
            .contentShape(DesignSystem.Radius.shape(theme.radius.card))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.labelPrimary)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the trip"))
    }

    private func eventDetails(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            flexibleRow {
                CDDateStamp(text: event.dateRangeLabel)
                if let slots = event.slotsLabel {
                    Text(slots)
                        .textRole(.footnote)
                        .foregroundStyle(CDColor.onBrandSoft)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(CDColor.brandSoft, in: Capsule())
                }
            }
            Text(event.title)
                .textRole(.title2, emphasized: true)
            if let place = event.place {
                CDMetaRow(icon: .mapPin, text: place)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private func eventFooter(_ event: Event) -> some View {
        flexibleRow(spacing: 8) {
            if let fee = event.feeLabel {
                Text(fee)
                    .foregroundStyle(theme.labelSecondary)
            }
            Spacer(minLength: 0)
            Text("See trip")
                .fontWeight(.semibold)
                .foregroundStyle(theme.accent)
        }
        .textRole(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Side by side normally, stacked at accessibility sizes.
    private func flexibleRow(
        spacing: CGFloat = 8,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        return layout { content() }
    }

    // MARK: - Pray today

    private func prayerCard(_ prayer: HomePrayer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pray today")
                    .textRole(.footnote)
                    .foregroundStyle(CDColor.onPineMuted)
                Spacer()
                CDLanes(width: 32, gap: 5, color: CDColor.lanesOnPine)
            }
            Text(prayer.body)
                .textRole(.title3)
                .foregroundStyle(CDColor.onPine)
            flexibleRow(spacing: 12) {
                Button { hasPrayed.toggle() } label: {
                    Text(hasPrayed ? "You prayed" : "I prayed")
                        .textRole(.subheadline, emphasized: true)
                        .foregroundStyle(CDColor.onPine)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .overlay(Capsule().stroke(CDColor.pineLine, lineWidth: 1))
                }
                .buttonStyle(.plain)
                if let prayed = prayedLabel(for: prayer) {
                    Text(prayed)
                        .textRole(.subheadline)
                        .foregroundStyle(CDColor.onPineMuted)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            CDColor.pineGround,
            in: DesignSystem.Radius.shape(theme.radius.card)
        )
    }

    /// The count, plus the reader's own prayer for as long as the screen lives.
    private func prayedLabel(for prayer: HomePrayer) -> String? {
        var shown = prayer
        shown.prayedCount += hasPrayed ? 1 : 0
        return shown.prayedLabel
    }

    // MARK: - Latest story

    private func storyCard(_ story: HomeStory) -> some View {
        HStack(spacing: 14) {
            DSRemoteImage(url: story.imageURL) { DSImagePlaceholder() }
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(story.title)
                    .textRole(.headline, emphasized: true)
                if !story.summary.isEmpty {
                    Text(story.summary)
                        .textRole(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: DesignSystem.Radius.shape(theme.radius.card))
        .overlay(
            DesignSystem.Radius.shape(theme.radius.card).stroke(theme.separator, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// A thin dashed line across the card.
private struct DashedRule: View {
    let color: Color

    var body: some View {
        Line()
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .frame(height: 1.5)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

// MARK: - Previews: one per state

@MainActor
private func previewViewModel(
    _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
) -> HomeViewModel {
    HomeViewModel(api: HomeAPI(client: StubHTTPClient(handler)))
}

#Preview("Loaded") {
    HomeView(viewModel: previewViewModel(SampleStub.handle), onOpenEvent: { _ in })
        .theme(.crossdrive)
}

#Preview("Loading") {
    HomeView(
        viewModel: previewViewModel { _ in
            try await Task.sleep(for: .seconds(3600))
            return .json("{}")
        },
        onOpenEvent: { _ in }
    )
    .theme(.crossdrive)
}

#Preview("Empty") {
    HomeView(viewModel: previewViewModel { _ in .json("{}") }, onOpenEvent: { _ in })
        .theme(.crossdrive)
}

#Preview("Error") {
    HomeView(viewModel: previewViewModel { _ in .json("{}", status: 500) }, onOpenEvent: { _ in })
        .theme(.crossdrive)
}

#Preview("Offline") {
    HomeView(
        viewModel: previewViewModel { _ in throw NetworkError.noConnection },
        onOpenEvent: { _ in }
    )
    .theme(.crossdrive)
}
