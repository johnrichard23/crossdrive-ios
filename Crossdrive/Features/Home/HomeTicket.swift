import DesignSystem
import SwiftUI

/// The "Next event" ticket: a dark top with the countdown, a torn
/// dashed edge with a notch each side, and a white bottom with the facts and
/// the one action that fits the person.
struct HomeTicket: View {
    let trip: HomeTrip
    let countdown: HomeCountdown?
    let photo: UIImage?
    let onRegister: () -> Void
    let onOpenTrip: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isLargeText: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpenTrip) { top }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens the trip"))
            bottom
                .overlay(alignment: .top) { tornEdge }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Dark top

    private var top: some View {
        VStack(alignment: .leading, spacing: 0) {
            if trip.isGoing {
                Text("You're going")
                    .textRole(.footnote, emphasized: true)
                    .foregroundStyle(CDColor.onBrandSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(CDColor.brandSoft, in: Capsule())
                    .padding(.bottom, 14)
            }
            if let countdown {
                Text(countdown.number)
                    .csDisplay(size: 76, lineHeight: 72, tracking: -1.5, singleLine: true)
                    .foregroundStyle(.white)
                Text(countdown.caption)
                    .textRole(.title3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: isLargeText ? .infinity : 200, alignment: .leading)
                    .padding(.top, 4)
            } else {
                Text(trip.event.title)
                    .textRole(.title2, emphasized: true)
                    .foregroundStyle(.white)
            }
            route
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) { photoCircle }
        .background(CDColor.pineBand)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(CDColor.pineBand)
                .shadow(color: .black.opacity(0.14), radius: 12, y: 10)
        }
    }

    @ViewBuilder private var route: some View {
        if let route = trip.route {
            let layout = isLargeText
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                Text(route.origin)
                if !isLargeText {
                    Line()
                        .stroke(CDColor.pineLine, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .frame(maxWidth: 56, minHeight: 2, maxHeight: 2)
                }
                Text(route.destination)
            }
            .textRole(.callout, emphasized: true)
            .foregroundStyle(.white)
            .lineLimit(isLargeText ? nil : 1)
            .padding(.top, 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("From \(route.origin) to \(route.destination)"))
        }
    }

    /// The round photo, 170 pt, with its corner cut off by the card's edge.
    @ViewBuilder private var photoCircle: some View {
        if !isLargeText {
            CDColor.pineGround
                .overlay {
                    if let photo {
                        Image(uiImage: photo).resizable().scaledToFill().transition(.opacity)
                    }
                }
                .clipShape(Circle())
                .overlay(Circle().stroke(CDColor.pineRing, lineWidth: 4))
                .frame(width: 170, height: 170)
                .offset(x: 44, y: -44)
                .animation(DesignSystem.Motion.enter, value: photo != nil)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Torn edge

    /// A dashed line across the seam, and a notch of the page colour each side.
    private var tornEdge: some View {
        ZStack(alignment: .top) {
            Line()
                .stroke(theme.separator, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                .frame(height: 2)
                .padding(.horizontal, 18)
            HStack {
                Circle().fill(theme.background).frame(width: 24, height: 24).offset(x: -12)
                Spacer()
                Circle().fill(theme.background).frame(width: 24, height: 24).offset(x: 12)
            }
            .offset(y: -12)
        }
        .accessibilityHidden(true)
    }

    // MARK: - White bottom

    private var bottom: some View {
        VStack(alignment: .leading, spacing: trip.isGoing ? 16 : 14) {
            if trip.isGoing {
                goingFacts
            } else {
                guestFacts
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28)
                .fill(theme.surface)
                .shadow(color: .black.opacity(0.14), radius: 12, y: 10)
        }
    }

    private var guestFacts: some View {
        VStack(alignment: .leading, spacing: 14) {
            sideBySide(alignment: .center) {
                CDDateStamp(text: trip.event.dateRangeLabel)
            } trailing: {
                if let fee = trip.event.fee?.formatted {
                    VStack(alignment: isLargeText ? .leading : .trailing, spacing: 2) {
                        Text("Cost").textRole(.footnote, emphasized: true)
                            .foregroundStyle(CDColor.captionMuted)
                        Text(fee).textRole(.headline, emphasized: true)
                    }
                }
            }
            if let days = trip.event.daysAndNights {
                Text(days)
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
                    .padding(.top, -4)
            }
            slots
            action
            Button("See what's included", action: onOpenTrip)
                .textRole(.subheadline, emphasized: true)
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, minHeight: DesignSystem.minTapTarget)
                .padding(.top, -6)
                .padding(.bottom, -4)
        }
    }

    @ViewBuilder private var slots: some View {
        if let label = slotsText {
            VStack(alignment: .leading, spacing: 6) {
                Rectangle()
                    .fill(CDColor.meterTrack)
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(theme.accent)
                                .frame(width: proxy.size.width * trip.event.takenFraction)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .accessibilityHidden(true)
                label
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
            }
        }
    }

    /// "**12 slots left** of 34", or "Full".
    private var slotsText: Text? {
        guard let capacity = trip.event.capacity, let left = trip.event.slotsLeftCount else {
            return nil
        }
        if trip.event.isFull || left == 0 {
            return Text("Full")
        }
        let count = Text(left == 1 ? "1 slot left" : "\(left) slots left")
            .fontWeight(.semibold)
            .foregroundStyle(CDColor.onBrandSoft)
        return count + Text(" of \(capacity)")
    }

    @ViewBuilder private var action: some View {
        switch trip.bar {
        case .register:
            Button("Register", action: onRegister).buttonStyle(CDPillButtonStyle())
        case .full:
            Text("Trip is full").textRole(.subheadline, emphasized: true)
            Button("Join the waitlist", action: onRegister).buttonStyle(CDPillButtonStyle())
        case .waitlisted:
            Text("You're on the waitlist").textRole(.subheadline, emphasized: true)
        case .closed:
            Text("Registration closed").textRole(.subheadline, emphasized: true)
        case .going:
            EmptyView()
        }
    }

    private var goingFacts: some View {
        VStack(alignment: .leading, spacing: 10) {
            sideBySide {
                VStack(alignment: .leading, spacing: 6) {
                    CDDateStamp(text: trip.event.dateRangeLabel)
                    Text(trip.event.startDayLabel)
                        .textRole(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                }
            } trailing: {
                if let meetup = trip.meetup {
                    VStack(alignment: isLargeText ? .leading : .trailing, spacing: 2) {
                        Text("Meet at \(meetup.point)")
                            .textRole(.footnote, emphasized: true)
                            .foregroundStyle(CDColor.captionMuted)
                        Text(meetup.time).textRole(.headline, emphasized: true)
                    }
                    .multilineTextAlignment(isLargeText ? .leading : .trailing)
                }
            }
            if case let .going(_, waiverSigned) = trip.bar, !waiverSigned {
                Text("Waiver not signed yet")
                    .textRole(.subheadline, emphasized: true)
                    .foregroundStyle(theme.warning)
                    .padding(.top, 6)
            }
        }
    }

    /// Side by side normally (the second at the trailing edge), stacked at
    /// accessibility sizes.
    private func sideBySide(
        alignment: VerticalAlignment = .top,
        @ViewBuilder _ leading: () -> some View,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        let layout = isLargeText
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: alignment, spacing: 12))
        return layout {
            leading()
            if !isLargeText {
                Spacer(minLength: 0)
            }
            trailing()
        }
    }
}

/// A horizontal line across its frame, for dashed strokes.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
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
