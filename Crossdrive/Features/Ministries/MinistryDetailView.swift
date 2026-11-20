import DataLayer
import DesignSystem
import SwiftUI

/// One ministry: a photo, what it is, photos, updates, how to pray, what is
/// needed, and a pinned Give bar.
struct MinistryDetailView: View {
    @State private var viewModel: MinistryDetailViewModel
    @State private var hasPrayed = false

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnline) private var isOnline
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(viewModel: MinistryDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .background(theme.background)
            .overlay(alignment: .top) { backButton }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .task { await viewModel.load() }
            .onChange(of: isOnline) { _, isOnline in
                if isOnline {
                    Task { await viewModel.connectionRestored() }
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

    private var skeleton: some View {
        ScrollView {
            VStack(spacing: theme.spacing.groupGap) {
                ForEach(0 ..< 3, id: \.self) { _ in DSSkeletonCard() }
            }
            .screenMargins()
            .padding(.top, 72)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Loading"))
        }
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
                DSRemoteImage(url: detail.ministry.imageURL) { DSImagePlaceholder() }
                    .frame(height: 260)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    intro(detail.ministry)
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

    private func intro(_ ministry: Ministry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let schedule = ministry.schedule {
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
            if let place = ministry.place {
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
            Button { hasPrayed.toggle() } label: {
                Text(hasPrayed ? "You prayed" : "I prayed")
                    .textRole(.subheadline, emphasized: true)
                    .foregroundStyle(theme.labelPrimary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .overlay(Capsule().stroke(theme.labelSecondary, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: hasPrayed)
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
        Button("Give to \(ministry.name)") {}
            .buttonStyle(.ds(.primary))
            .screenMargins()
            .padding(.top, 14)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
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
        ministryID: "bible-studies"
    )
}

#Preview("Loaded") {
    MinistryDetailView(viewModel: previewViewModel(SampleStub.handle)).theme(.crossdrive)
}

#Preview("Loading") {
    MinistryDetailView(
        viewModel: previewViewModel { _ in
            try await Task.sleep(for: .seconds(3600))
            return .json("{}")
        }
    )
    .theme(.crossdrive)
}

#Preview("Not available") {
    MinistryDetailView(viewModel: previewViewModel { _ in .json("{}", status: 404) })
        .theme(.crossdrive)
}

#Preview("Error") {
    MinistryDetailView(viewModel: previewViewModel { _ in .json("{}", status: 500) })
        .theme(.crossdrive)
}

#Preview("Offline") {
    MinistryDetailView(viewModel: previewViewModel { _ in throw NetworkError.noConnection })
        .theme(.crossdrive)
}
