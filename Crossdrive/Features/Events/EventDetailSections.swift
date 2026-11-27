import DesignSystem
import SwiftUI

// Each section of the trip detail is its own small view that takes only the
// data it shows, so a change to one part does not redraw the others.

/// A section title with the lanes mark above it.
struct EventSection<Content: View>: View {
    let title: LocalizedStringKey
    /// Space between the items inside the section.
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CDLanes(color: theme.accent)
            Text(title)
                .textRole(.title3, emphasized: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 10)
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding(.top, 14)
        }
    }
}

// MARK: - Band

/// The pine band of facts under the hero: people, travel time, slots.
struct EventBand: View {
    let stats: [EventBandStat]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
        layout {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                if index > 0 {
                    divider
                }
                VStack(
                    alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center,
                    spacing: 2
                ) {
                    Text(stat.value)
                        .textRole(.title3, emphasized: true)
                        .foregroundStyle(CDColor.onPine)
                    Text(stat.label)
                        .textRole(.footnote)
                        .foregroundStyle(CDColor.onPineMuted)
                }
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                .frame(
                    maxWidth: .infinity,
                    alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center
                )
                .padding(.vertical, 18)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(CDColor.pineBand)
    }

    @ViewBuilder private var divider: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Rectangle().fill(CDColor.pineDivider).frame(height: 1)
        } else {
            Rectangle().fill(CDColor.pineDivider).frame(width: 1).padding(.vertical, 18)
        }
    }
}

// MARK: - Map

/// "Where we're going": a still picture of the place. Tapping opens Apple Maps.
struct EventMapSection: View {
    /// The map picture's height; the view model draws the map at this size.
    static let height: CGFloat = 210

    let location: EventLocation
    let image: UIImage?
    /// Called with the size the picture is shown at, when it is known or changes.
    let onSize: (CGSize) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        EventSection(title: "Where we're going") {
            mapPicture
            Text(location.caption)
                .textRole(.subheadline)
                .foregroundStyle(theme.labelSecondary)
        }
    }

    private var mapPicture: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .transition(.opacity)
                } else {
                    theme.surfacePressed
                }
                pin
            }
            .onAppear { onSize(proxy.size) }
            .onChange(of: proxy.size) { _, size in onSize(size) }
        }
        .frame(height: Self.height)
        .clipShape(DesignSystem.Radius.shape(16))
        .overlay { openInMaps }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Map of \(location.name)"))
        .accessibilityAddTraits(.isLink)
        .accessibilityAction {
            if let url = location.mapsURL {
                openURL(url)
            }
        }
    }

    private var pin: some View {
        Circle()
            .fill(theme.accent)
            .frame(width: 26, height: 26)
            .overlay(Circle().fill(theme.onAccent).frame(width: 10, height: 10))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }

    @ViewBuilder private var openInMaps: some View {
        if let url = location.mapsURL {
            Link(destination: url) { Color.clear }
        }
    }
}

// MARK: - Why we go

struct EventWhySection: View {
    let quote: String
    let background: String

    @Environment(\.theme) private var theme

    var body: some View {
        EventSection(title: "Why we go") {
            if !quote.isEmpty {
                Text(quote)
                    .textRole(.title2, emphasized: true)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(theme.accent).frame(width: 3)
                    }
            }
            if !background.isEmpty {
                Text(background)
                    .textRole(.body)
                    .foregroundStyle(theme.labelSecondary)
            }
        }
    }
}

// MARK: - Covers

/// "What ₱1,500 covers": the items the trip lists, as a grid or a list.
struct EventCoversSection: View {
    let title: String
    let covers: [EventCover]
    let fitsGrid: Bool
    let notCovered: String?

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        EventSection(title: LocalizedStringKey(title)) {
            if fitsGrid, !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(covers) { cover in tile(cover) }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(covers) { cover in row(cover) }
                }
            }
            if let notCovered {
                Text("**Not covered:** \(notCovered)")
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
            }
        }
    }

    private func tile(_ cover: EventCover) -> some View {
        VStack(spacing: 10) {
            EventIconBadge(key: cover.iconKey)
            Text(cover.name)
                .textRole(.headline, emphasized: true)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(theme.surface, in: DesignSystem.Radius.shape(12))
        .overlay(DesignSystem.Radius.shape(12).stroke(theme.separator, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func row(_ cover: EventCover) -> some View {
        EventRow(iconKey: cover.iconKey, title: cover.name, subtitle: nil)
    }
}

// MARK: - Roles

struct EventRolesSection: View {
    let roles: [EventRole]

    var body: some View {
        EventSection(title: "Roles you can take", spacing: 0) {
            ForEach(roles) { role in
                EventRow(
                    iconKey: role.iconKey,
                    title: role.name,
                    subtitle: role.summary.isEmpty ? nil : role.summary
                )
            }
        }
    }
}

/// An icon badge, a title and an optional line, with a line under it.
struct EventRow: View {
    let iconKey: String?
    let title: String
    let subtitle: String?

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: 12) {
            EventIconBadge(key: iconKey)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textRole(.headline, emphasized: true)
                if let subtitle {
                    Text(subtitle)
                        .textRole(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.separator).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}

struct EventIconBadge: View {
    let key: String?

    var body: some View {
        DSIcon(EventIcon.source(for: key), role: .body)
            .foregroundStyle(CDColor.onBrandSoft)
            .padding(8)
            .frame(minWidth: 40, minHeight: 40)
            .background(CDColor.brandSoft, in: DesignSystem.Radius.shape(12))
    }
}

// MARK: - Bring

/// "What to bring": a plain list. Not tickable; the checklist lives in My trip.
struct EventBringSection: View {
    let items: [String]

    @Environment(\.theme) private var theme

    var body: some View {
        EventSection(title: "What to bring", spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 12) {
                    DSIcon(.check, role: .body).foregroundStyle(theme.accent)
                    Text(item).textRole(.body)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 54)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(theme.separator).frame(height: 1)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Going

/// The card for a person who is going: where they stand, where and when to
/// meet, and what is left. The way into My trip is the pinned bar's button.
struct EventGoingCard: View {
    let meetup: EventMeetup?
    /// "Saturday, Dec 12".
    let day: String
    /// "Starts in 16 days".
    let countdown: String?
    let waiverSigned: Bool
    let onOpenTrip: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconTile: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CDFlowLayout(spacing: 8) {
                MyTripStatusTag(status: .going)
                    .fixedSize()
                if let countdown {
                    Text(countdown)
                        .textRole(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if let meetup {
                divider
                HStack(spacing: 12) {
                    tile(.mapPin, foreground: theme.accent, fill: CDColor.brandSoft)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meetup.point).textRole(.body, emphasized: true)
                        Text("\(day) · \(meetup.time)")
                            .textRole(.subheadline)
                            .foregroundStyle(theme.labelSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Meet at \(meetup.point), \(day), \(meetup.time)"))
            }

            if !waiverSigned {
                divider
                Button(action: onOpenTrip) {
                    HStack(spacing: 12) {
                        tile(
                            .system("doc.text"),
                            foreground: CDColor.onHarvestSoft,
                            fill: CDColor.harvestSoft
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Waiver not signed yet").textRole(.body, emphasized: true)
                            Text("Sign it before you board. It takes a minute.")
                                .textRole(.subheadline)
                                .foregroundStyle(theme.labelSecondary)
                        }
                        Spacer(minLength: 0)
                        DSIcon(.chevronRight, role: .subheadline)
                            .foregroundStyle(theme.labelTertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens My trip"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: DesignSystem.Radius.shape(16))
        .overlay(DesignSystem.Radius.shape(16).stroke(theme.separator, lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(theme.surfacePressed).frame(height: 1)
    }

    /// At the largest sizes the words need the width more than the icon does.
    @ViewBuilder
    private func tile(_ icon: DSIcon.Source, foreground: Color, fill: Color) -> some View {
        if !dynamicTypeSize.isAccessibilitySize {
            DSIcon(icon, role: .body)
                .foregroundStyle(foreground)
                .frame(width: iconTile, height: iconTile)
                .background(fill, in: DesignSystem.Radius.shape(10))
                .accessibilityHidden(true)
        }
    }
}

#Preview("Going card") {
    EventGoingCard(
        meetup: EventMeetup(point: "Magallanes port", time: "5:30 AM"),
        day: "Saturday, Dec 12",
        countdown: "Starts in 16 days",
        waiverSigned: false,
        onOpenTrip: {}
    )
    .padding()
    .theme(.crossdrive)
}
