import DesignSystem
import SwiftUI

/// The "Next event" card: the first day as a gold tile with the trip's name and
/// route, a row of fact chips, and the trip's photo with a frosted Details button.
/// Registering starts on Trip detail, so the card has no register button. For
/// someone going it is a short ticket into My trip instead.
struct HomeTripCard: View {
    let trip: HomeTrip
    let photo: UIImage?
    let onOpenTrip: () -> Void
    /// Opens My trip; only shown when the person is going.
    var onOpenMyTrip: (() -> Void)?

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static let photoHeight: CGFloat = 236
    /// Shorter than the guest photo: the going card leads with the meet time.
    static let goingPhotoHeight: CGFloat = 180

    private var isLargeText: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        Group {
            if trip.isGoing, let onOpenMyTrip {
                going(onOpenMyTrip)
                    .background {
                        // On the shape only: the ticket notches must not cast a shadow.
                        DesignSystem.Radius.shape(28).fill(CDColor.pineGround)
                            .modifier(CardShadow())
                    }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    chips
                    photoButton
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface, in: DesignSystem.Radius.shape(28))
                .modifier(CardShadow())
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Going

    /// For someone going, a ticket: the trip's photo and name, then a tear line,
    /// then when and where to meet, what is left, and the way into My trip.
    private func going(_ onOpenMyTrip: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpenTrip) { goingPhoto }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens \(trip.event.title)"))
            // At the largest sizes the words don't fit on the photo, so they sit under it.
            if isLargeText {
                VStack(alignment: .leading, spacing: 8) {
                    MyTripStatusTag(status: .going, compact: true)
                    TimelineView(.everyMinute) { context in
                        if let countdown = trip.countdown(now: context.date) {
                            Text(countdown)
                                .textRole(.subheadline)
                                .foregroundStyle(CDColor.onPineMuted)
                        }
                    }
                    titleAndDates
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            TicketEdge()
                .padding(.vertical, 14)
            ticketStub(onOpenMyTrip)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Below the tear line: when and where to meet, what is left, and the way in.
    private func ticketStub(_ onOpenMyTrip: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let meetup = trip.meetup {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meet at \(meetup.point)")
                        .textRole(.footnote)
                        .foregroundStyle(CDColor.onPineMuted)
                    Text(meetup.time)
                        .csDisplay(size: 44, lineHeight: 48, tracking: -1.2)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .accessibilityElement(children: .combine)
            }
            if trip.toDoCount > 0 {
                Button(action: onOpenMyTrip) {
                    Text(MyTripView.bannerTitle(count: trip.toDoCount))
                        .textRole(.footnote, emphasized: true)
                        .foregroundStyle(CDColor.onHarvestSoft)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(CDColor.harvestSoft, in: Capsule())
                        .frame(minHeight: DesignSystem.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens My trip"))
                .padding(.top, 4)
            }
            Button("Open my trip", action: onOpenMyTrip)
                .buttonStyle(.ds(.primary))
                .padding(.top, 14)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    /// The trip's photo, with where you stand at the top and the trip's name
    /// on a fade into the ticket at the bottom.
    private var goingPhoto: some View {
        CDColor.pineGround
            .frame(height: Self.goingPhotoHeight)
            .overlay {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if !isLargeText {
                    LinearGradient(
                        colors: [CDColor.pineGround.opacity(0), CDColor.pineGround],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 96)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if !isLargeText {
                    titleAndDates
                        .padding(.horizontal, 18)
                        .padding(.bottom, 2)
                }
            }
            .overlay(alignment: .topLeading) {
                if !isLargeText {
                    goingPill.padding(12)
                }
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .animation(DesignSystem.Motion.enter, value: photo != nil)
    }

    private var titleAndDates: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(trip.event.title)
                .textRole(.title3, emphasized: true)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text(datesAndPlace)
                .textRole(.subheadline)
                .foregroundStyle(CDColor.onPine)
        }
    }

    /// "✓ Going · Starts in 16 days", frosted so it reads on any photo.
    private var goingPill: some View {
        HStack(spacing: 6) {
            Label { Text("Going") } icon: { DSIcon(.check, role: .footnote) }
                .labelStyle(.titleAndIcon)
                .foregroundStyle(theme.success)
                .fixedSize()
            TimelineView(.everyMinute) { context in
                if let countdown = trip.countdown(now: context.date) {
                    HStack(spacing: 6) {
                        Text(verbatim: "·").accessibilityHidden(true)
                        Text(countdown)
                    }
                }
            }
        }
        .textRole(.footnote, emphasized: true)
        .foregroundStyle(theme.labelPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    /// "Dec 12 to 14 · Bagatao Island".
    private var datesAndPlace: String {
        guard let place = trip.event.place, !place.isEmpty else { return trip.event.dateRangeLabel }
        return String(localized: "\(trip.event.dateRangeLabel) · \(place)")
    }

    // MARK: - Header

    private var header: some View {
        let layout = isLargeText
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            CDDateTile(
                day: trip.event.startDayNumber,
                month: trip.event.startMonthAbbreviation,
                spokenMonth: trip.event.startMonthName
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.event.title)
                    .textRole(.headline, emphasized: true)
                    .accessibilityAddTraits(.isHeader)
                if let line = placeLine {
                    Text(line)
                        .textRole(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    /// "Magallanes to Bagatao Island", or just the place when the start is not known.
    private var placeLine: String? {
        if let route = trip.route {
            return String(localized: "\(route.origin) to \(route.destination)")
        }
        return trip.event.place
    }

    // MARK: - Chips

    private var chips: some View {
        CDFlowLayout(spacing: 6) {
            switch trip.bar {
            case .waitlisted:
                CDChip(text: String(localized: "On the waitlist"), tone: .status)
            case .closed:
                CDChip(text: String(localized: "Registration closed"), tone: .status)
            case .register, .full, .going:
                EmptyView()
            }
            if let days = trip.event.daysAndNights {
                CDChip(text: days)
            }
            if let fee = trip.event.fee?.formatted {
                CDChip(text: fee)
            }
            if let slots = trip.event.slotsLabel {
                CDChip(text: slots)
            }
        }
    }

    // MARK: - Photo

    private var photoButton: some View {
        Button(action: onOpenTrip) {
            CDColor.pineGround
                .frame(height: Self.photoHeight)
                .overlay {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .bottomTrailing) { detailsPill.padding(12) }
                .clipShape(DesignSystem.Radius.shape(22))
                .animation(DesignSystem.Motion.enter, value: photo != nil)
                .contentShape(DesignSystem.Radius.shape(22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Details"))
        .accessibilityHint(Text("Opens \(trip.event.title)"))
    }

    /// Frosted, so it reads as part of the photo and leaves the purple for real actions.
    private var detailsPill: some View {
        Text("Details")
            .textRole(.callout, emphasized: true)
            .foregroundStyle(theme.labelPrimary)
            .padding(.horizontal, 22)
            .frame(minHeight: DesignSystem.minTapTarget)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
    }
}

/// Shown when no trip is planned yet; the stories still show below it.
struct HomeNoTripCard: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No trip planned yet.").textRole(.title3, emphasized: true)
            Text("When the team sets the dates, the next trip shows up here.")
                .textRole(.callout)
                .foregroundStyle(theme.labelSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: DesignSystem.Radius.shape(theme.radius.card))
        .accessibilityElement(children: .combine)
    }
}

/// The card's lift off the page.
private struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }
}
