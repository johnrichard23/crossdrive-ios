import DesignSystem
import SwiftUI

/// "Mission stories": the latest film as one large card.
struct HomeStories: View {
    let story: HomeStory
    let photo: UIImage?
    let height: CGFloat
    let onWatch: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                CDLanes(color: theme.accent)
                Text("Mission stories")
                    .textRole(.title3, emphasized: true)
                    .accessibilityAddTraits(.isHeader)
                Text("The latest first, then the trips before it")
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
            }
            card.padding(.top, 14)
        }
    }

    @ViewBuilder private var card: some View {
        let content = CDColor.pineGround
            .frame(height: height)
            .overlay {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: CDColor.pineGround.opacity(0.05), location: 0.2),
                        .init(color: CDColor.pineGround.opacity(0.9), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .topLeading) { latest }
            .overlay(alignment: .bottomLeading) { text }
            .clipShape(DesignSystem.Radius.shape(26))
            .animation(DesignSystem.Motion.enter, value: photo != nil)
        if story.filmURL != nil {
            Button(action: onWatch) { content }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text("\(story.title), the latest mission trip story. Watch the film")
                )
        } else {
            content.accessibilityElement(children: .combine)
        }
    }

    private var latest: some View {
        Text("Latest")
            .textRole(.footnote, emphasized: true)
            .foregroundStyle(CDColor.onHarvest)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.94), in: Capsule())
            .padding(12)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\u{201C}\(story.quote)\u{201D}")
                .csDisplay(size: 40, lineHeight: 42, tracking: -0.4)
                .foregroundStyle(.white)
            if let madeBy = story.madeBy {
                Text(madeBy).textRole(.subheadline).foregroundStyle(CDColor.onScrimMuted)
            }
            if story.filmURL != nil {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .foregroundStyle(CDColor.onHarvest)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                    Text("Watch the film").textRole(.subheadline, emphasized: true)
                }
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(18)
    }
}
