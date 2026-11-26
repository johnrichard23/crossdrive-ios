import DesignSystem
import SwiftUI

/// The Pine ticket on My trip: where and when to meet, then Directions and a
/// call to the lead. The time is the biggest thing on the screen.
struct MyTripMeetCard: View {
    let meetup: MyTrip.Meetup
    let lead: MyTrip.Lead?

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Meet at")
                    .textRole(.footnote)
                    .foregroundStyle(CDColor.onPineMuted)
                Text(meetup.point)
                    .textRole(.title2, emphasized: true)
                    .foregroundStyle(CDColor.onPine)
                Text(MyTrip.time.format(meetup.startsAt))
                    .csDisplay(size: 64, lineHeight: 66, tracking: -1.9)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                CDDateStamp(text: MyTrip.longDay.format(meetup.startsAt))
                    .padding(.top, 6)
            }
            .accessibilityElement(children: .combine)

            TicketEdge(inset: 20)
                .padding(.vertical, 14)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { buttons }
                VStack(spacing: 10) { buttons }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CDColor.pineGround, in: DesignSystem.Radius.shape(20))
    }

    @ViewBuilder private var buttons: some View {
        if let url = mapsURL {
            Button("Directions") { openURL(url) }
                .buttonStyle(PineOutlineButtonStyle())
        }
        if let lead, let url = callURL(lead.phone) {
            Button("Call \(lead.name)") { openURL(url) }
                .buttonStyle(PineOutlineButtonStyle())
        }
    }

    /// Apple Maps over HTTPS; no location permission is needed to open it.
    private var mapsURL: URL? {
        guard let latitude = meetup.latitude, let longitude = meetup.longitude else { return nil }
        var parts = URLComponents(string: "https://maps.apple.com/")
        parts?.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: meetup.point),
        ]
        return parts?.url
    }

    /// Only digits and a leading plus reach the dialler.
    private func callURL(_ phone: String?) -> URL? {
        guard let phone else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(digits)")
    }
}

/// A dashed tear line with a notch cut at each end, like a ticket stub.
/// `inset` is the card's side padding, so the line and notches reach its edges.
struct TicketEdge: View {
    var inset: CGFloat = 0

    @Environment(\.theme) private var theme

    var body: some View {
        Line()
            .stroke(CDColor.pineDivider, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            .frame(height: 1.5)
            .padding(.horizontal, -inset)
            .overlay(alignment: .leading) { notch.offset(x: -inset - 9) }
            .overlay(alignment: .trailing) { notch.offset(x: inset + 9) }
            .accessibilityHidden(true)
    }

    private var notch: some View {
        Circle().fill(theme.background).frame(width: 18, height: 18)
    }
}

/// A horizontal line across the card's width.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// The outlined buttons on the Pine card.
struct PineOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textRole(.callout, emphasized: true)
            .foregroundStyle(CDColor.onPine)
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay(
                DesignSystem.Radius.shape(12).stroke(CDColor.pineLine, lineWidth: 1)
            )
            .contentShape(DesignSystem.Radius.shape(12))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
