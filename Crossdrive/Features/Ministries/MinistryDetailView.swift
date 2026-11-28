import DataLayer
import DesignSystem
import SwiftUI

/// One ministry: a photo, what it is, photos, updates, how to pray, what is
/// needed, and a pinned Give bar. The school fund shows its progress and what
/// one kid needs instead.
struct MinistryDetailView: View {
    @State private var viewModel: MinistryDetailViewModel
    /// Opens the giving sheet.
    private let onGive: (Ministry) -> Void
    /// The screen's width, known before anything shows, so the top photo can
    /// be made ready at its real size while the skeleton is up.
    @State private var containerWidth: CGFloat = 0

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnline) private var isOnline
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    private static let heroHeight: CGFloat = 260

    init(viewModel: MinistryDetailViewModel, onGive: @escaping (Ministry) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onGive = onGive
    }

    var body: some View {
        content
            .background(theme.background)
            .overlay(alignment: .top) { backButton }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .dsToast($viewModel.toast)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
            .task(id: containerWidth > 0) {
                guard containerWidth > 0 else { return }
                await viewModel.load(heroPixels: heroPixels)
            }
            .onAppear { viewModel.isOnline = isOnline }
            .onChange(of: isOnline) { _, isOnline in
                viewModel.isOnline = isOnline
                if isOnline {
                    Task { await viewModel.connectionRestored(heroPixels: heroPixels) }
                }
            }
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
                "This ministry isn't available.",
                message: "It may have been taken down. See the ministries that are open.",
                systemImage: "person.2",
                actionTitle: "See ministries",
                action: { dismiss() }
            )
        case .failed:
            DSStateView.error(message: "Check your connection, then try again.") {
                Task { await viewModel.load() }
            }
        case .offline:
            DSStateView.offline { Task { await viewModel.load() } }
        }
    }

    private var heroPixels: Int {
        ImageDownsampler.maxPixels(
            for: CGSize(width: containerWidth, height: Self.heroHeight),
            scale: displayScale
        )
    }

    /// Grey blocks shaped like the page: the photo, the stamp, the title, the
    /// summary, the place, then the photos row.
    private var skeleton: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(theme.surfacePressed)
                    .frame(height: Self.heroHeight)
                VStack(alignment: .leading, spacing: 12) {
                    block(width: 96, height: 24, radius: 4)
                    block(width: 260, height: 32, radius: 8)
                    block(height: 16, radius: 6)
                    block(width: 220, height: 16, radius: 6)
                    block(width: 200, height: 18, radius: 6)
                    block(width: 90, height: 22, radius: 6).padding(.top, 10)
                    HStack(spacing: 10) {
                        block(width: 208, height: 148, radius: 16)
                        block(width: 208, height: 148, radius: 16)
                    }
                }
                .screenMargins()
                .padding(.top, 16)
            }
            .dsLoading(true)
        }
        .scrollDisabled(true)
        .ignoresSafeArea(edges: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading"))
    }

    private func block(width: CGFloat? = nil, height: CGFloat, radius: CGFloat) -> some View {
        DesignSystem.Radius.shape(radius)
            .fill(theme.surfacePressed)
            .frame(maxWidth: width ?? .infinity, alignment: .leading)
            .frame(width: width, height: height)
    }

    private var backButton: some View {
        HStack {
            Button { dismiss() } label: {
                DSIcon(.chevronLeft, role: .body)
                    .foregroundStyle(theme.labelPrimary)
                    .padding(10)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(theme.surface, in: Circle())
                    .shadow(color: .black.opacity(0.16), radius: 3, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Back to Ministries"))
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Detail

    private func detailScreen(_ detail: MinistryDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(detail.ministry)
                VStack(alignment: .leading, spacing: 12) {
                    intro(detail.ministry)
                    if detail.ministry.kind == .school, let fund = detail.ministry.fund {
                        MinistryFundProgress(fund: fund)
                        if !fund.costs.isEmpty {
                            MinistryFundCosts(costs: fund.costs).padding(.top, 10)
                        }
                    } else {
                        sections(detail)
                    }
                    if dynamicTypeSize.isAccessibilitySize {
                        giveBar(detail.ministry)
                            .padding(.horizontal, -theme.spacing.screenMarginCompact)
                    }
                }
                .screenMargins()
                .padding(.top, 16)
                .padding(.bottom, theme.spacing.groupGap)
            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // At accessibility sizes the bar would fill the screen, so it scrolls with the page.
            if !dynamicTypeSize.isAccessibilitySize {
                giveBar(detail.ministry)
                    .background(.regularMaterial)
                    .overlay(alignment: .top) { Rectangle().fill(theme.separator).frame(height: 1) }
            }
        }
    }

    @ViewBuilder private func sections(_ detail: MinistryDetail) -> some View {
        if !detail.photos.isEmpty {
            MinistryPhotosSection(photos: detail.photos)
        }
        if !detail.updates.isEmpty {
            MinistryUpdatesSection(updates: detail.updates)
        }
        if let prayer = detail.prayer {
            prayerSection(prayer)
        }
        if let need = detail.need {
            needSection(need)
        }
    }

    /// The photo loaded with the page when it came in time, else the remote one.
    /// Drawn over a fixed-size frame: a filled photo would otherwise widen the page.
    private func hero(_ ministry: Ministry) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: Self.heroHeight)
            .overlay {
                if let image = viewModel.heroImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    DSRemoteImage(url: ministry.heroURL) { DSImagePlaceholder() }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private func intro(_ ministry: Ministry) -> some View {
        let isFund = ministry.kind == .school
        return VStack(alignment: .leading, spacing: 12) {
            if isFund {
                CDDateStamp(text: String(localized: "This school year"))
            } else if let schedule = ministry.schedule {
                CDDateStamp(text: schedule)
            }
            Text(ministry.name)
                .textRole(.title1, emphasized: true)
                .accessibilityAddTraits(.isHeader)
            if !ministry.summary.isEmpty {
                Text(ministry.summary)
                    .textRole(.callout)
                    .foregroundStyle(theme.labelSecondary)
            }
            if !isFund, let place = ministry.place {
                CDMetaRow(icon: .mapPin, text: place, role: .callout)
            }
        }
    }

    // MARK: - Prayer and need

    private func prayerSection(_ prayer: HomePrayer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("How to pray")
            VStack(alignment: .leading, spacing: 10) {
                Text(prayer.body)
                    .textRole(.callout)
                prayRow(prayer)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: DesignSystem.Radius.shape(16))
            .overlay(DesignSystem.Radius.shape(16).stroke(theme.separator, lineWidth: 1))
        }
        .padding(.top, 10)
    }

    private func prayRow(_ prayer: HomePrayer) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            if let prayed = prayer.prayedLabel {
                Text(prayed)
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            Button { Task { await viewModel.pray() } } label: {
                Text(viewModel.hasPrayed ? "You prayed" : "I prayed")
                    .textRole(.subheadline, emphasized: true)
                    .foregroundStyle(theme.labelPrimary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .overlay(Capsule().stroke(theme.labelSecondary, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: viewModel.hasPrayed) { _, prayed in prayed }
        }
    }

    private func needSection(_ need: MinistryNeed) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("What's needed")
            VStack(alignment: .leading, spacing: 8) {
                Text(need.title)
                    .textRole(.subheadline, emphasized: true)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(need.raised.formatted)
                        .textRole(.title2, emphasized: true)
                    Text("raised of \(need.goal.formatted)")
                        .textRole(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                }
                progressBar(need.fraction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: DesignSystem.Radius.shape(16))
            .overlay(DesignSystem.Radius.shape(16).stroke(theme.separator, lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text("\(Int((need.fraction * 100).rounded())) percent of the goal"))
        }
        .padding(.top, 10)
    }

    private func progressBar(_ fraction: Double) -> some View {
        Capsule()
            .fill(theme.surfacePressed)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .accessibilityHidden(true)
    }

    // MARK: - Give bar

    private func giveBar(_ ministry: Ministry) -> some View {
        MinistryGiveBar(ministry: ministry) { onGive(ministry) }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        MinistrySectionHeader(title: title)
    }
}

// MARK: - Previews: one per state

@MainActor
private func previewViewModel(
    _ handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse
) -> MinistryDetailViewModel {
    MinistryDetailViewModel(
        api: MinistriesAPI(client: StubHTTPClient(handler)),
        ministryID: "bible-studies",
        imageLoader: URLSessionImageLoader()
    )
}

#Preview("Loaded") {
    MinistryDetailView(viewModel: previewViewModel(SampleStub.handle), onGive: { _ in })
        .theme(.crossdrive)
}

#Preview("Loading") {
    MinistryDetailView(
        viewModel: previewViewModel { _ in
            try await Task.sleep(for: .seconds(3600))
            return .json("{}")
        },
        onGive: { _ in }
    )
    .theme(.crossdrive)
}

#Preview("Not available") {
    MinistryDetailView(
        viewModel: previewViewModel { _ in .json("{}", status: 404) },
        onGive: { _ in }
    )
    .theme(.crossdrive)
}

#Preview("Error") {
    MinistryDetailView(
        viewModel: previewViewModel { _ in .json("{}", status: 500) },
        onGive: { _ in }
    )
    .theme(.crossdrive)
}

#Preview("Offline") {
    MinistryDetailView(
        viewModel: previewViewModel { _ in throw NetworkError.noConnection },
        onGive: { _ in }
    )
    .theme(.crossdrive)
}
