import DesignSystem
import SwiftUI

/// The "Next event" card: the first day as a gold tile with the trip's name and
/// route, a row of fact chips, and the trip's photo with a frosted Details button.
/// Registering starts on Trip detail, so the card has no register button.
struct HomeTripCard: View {
    let trip: HomeTrip
    let photo: UIImage?
    let onOpenTrip: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static let photoHeight: CGFloat = 236

    private var isLargeText: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            chips
            photoButton
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: DesignSystem.Radius.shape(28))
        .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
        .accessibilityElement(children: .contain)
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
            case .going:
                CDChip(text: String(localized: "You're going"), tone: .status)
            case .waitlisted:
                CDChip(text: String(localized: "On the waitlist"), tone: .status)
            case .closed:
                CDChip(text: String(localized: "Registration closed"), tone: .status)
            case .register, .full:
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
            if let meetup = trip.meetup {
                CDChip(text: String(localized: "Meet at \(meetup.point) \(meetup.time)"))
            }
            if case let .going(_, waiverSigned) = trip.bar, !waiverSigned {
                CDChip(text: String(localized: "Waiver not signed yet"), tone: .warning)
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
