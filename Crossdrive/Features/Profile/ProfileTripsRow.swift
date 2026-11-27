import DesignSystem
import SwiftUI

/// Profile › Your trips: up to three photo tiles, each opening My trip. Side by
/// side, or one under another at the largest text sizes.
struct ProfileTripsRow: View {
    let trips: [MyTrip]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileHeight: CGFloat = 132

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            ForEach(trips) { trip in
                NavigationLink(value: EventsRoute.myTrip(trip.id)) {
                    tile(trip)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tile(_ trip: MyTrip) -> some View {
        // A trip without a photo gets a plain dark tile, so the white name stays readable.
        DSRemoteImage(url: trip.event.heroImageURL) { CDColor.pineBand }
            .frame(maxWidth: .infinity, minHeight: tileHeight, maxHeight: tileHeight)
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: CDColor.pineGround.opacity(0), location: 0.35),
                        .init(color: CDColor.pineGround.opacity(0.8), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .topLeading) {
                MyTripStatusTag(status: trip.status, compact: true)
                    .padding(8)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(trip.event.name)
                        .textRole(.subheadline, emphasized: true)
                        .foregroundStyle(.white)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    Text(trip.dateRangeLabel)
                        .textRole(.caption1)
                        .foregroundStyle(CDColor.onScrimMuted)
                }
                .padding(10)
            }
            .clipShape(DesignSystem.Radius.shape(16))
            .contentShape(DesignSystem.Radius.shape(16))
            .accessibilityElement(children: .combine)
    }
}

/// The trips row while it loads: three grey tiles the size of the real ones.
struct ProfileTripsSkeleton: View {
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var tileHeight: CGFloat = 132

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< ProfileSummary.tripsShown, id: \.self) { _ in
                DesignSystem.Radius.shape(16)
                    .fill(theme.surfacePressed)
                    .frame(height: tileHeight)
            }
        }
        .dsLoading(true)
        .accessibilityLabel("Loading your trips")
    }
}
