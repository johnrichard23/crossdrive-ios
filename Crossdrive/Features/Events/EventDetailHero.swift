import DesignSystem
import SwiftUI

/// The photo at the top of a trip: date stamp, kind, title and "place · days".
struct EventHero: View {
    let event: Event
    let height: CGFloat
    /// The photo, ready-decoded by the view model. While it is `nil` the hero
    /// shows the Pine ground, then the photo fades in if it arrives late.
    let image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            photo
                .frame(height: height)
                .accessibilityHidden(true)
            LinearGradient(
                colors: [.clear, CDColor.pineGround.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.56)
            .accessibilityHidden(true)
            text
        }
        .frame(height: height)
        .clipped()
        .animation(DesignSystem.Motion.enter, value: image != nil)
    }

    /// The Pine ground, with the photo laid over it. The photo is an overlay so it
    /// is cropped to the ground's size and can never make the screen wider.
    private var photo: some View {
        CDColor.pineGround
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipped()
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 8) {
            tags
            Text(event.title)
                .textRole(.title1, emphasized: true)
                .foregroundStyle(CDColor.onPine)
                .accessibilityAddTraits(.isHeader)
            if let line = subtitle {
                Text(line)
                    .textRole(.callout)
                    .foregroundStyle(CDColor.onPine.opacity(0.92))
            }
        }
        .padding(16)
    }

    private var tags: some View {
        HStack(spacing: 8) {
            CDDateStamp(text: event.dateRangeLabel)
            Text(event.kind.tagLabel)
                .textRole(.footnote, emphasized: true)
                .foregroundStyle(CDColor.onBrandSoft)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(CDColor.brandSoft, in: Capsule())
        }
    }

    /// "Bagatao Island · 3 days, 2 nights".
    private var subtitle: String? {
        let parts = [event.place, event.daysAndNights].compactMap(\.self).filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
