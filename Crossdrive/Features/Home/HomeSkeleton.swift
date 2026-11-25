import DesignSystem
import SwiftUI

extension HomeTrip {
    /// A made-up trip with every part present, so the placeholder card has the
    /// same shape as the real one. Its words are never read: they are redacted.
    static let placeholder = HomeTrip(
        event: Event.placeholders[0],
        fromPlace: "Placeholder place",
        registration: nil,
        meetup: nil
    )
}

extension HomeStory {
    static let placeholder = HomeStory(
        id: "placeholder",
        title: "Placeholder story",
        quote: "A short quote from the latest story.",
        madeBy: "Made by the youth of the place",
        imageURL: nil,
        filmURL: nil
    )
}

/// What Home shows while it loads: the real card and film card with made-up
/// words, greyed and shimmering, so nothing moves when the content arrives.
struct HomeSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Next event").textRole(.title3, emphasized: true)
                    HomeTripCard(trip: .placeholder, photo: nil, onOpenTrip: {})
                }
                HomeStories(story: .placeholder, photo: nil, height: 300, onWatch: {})
            }
            // Grey and faint, like the other skeletons.
            .saturation(0)
            .opacity(0.5)
            .dsLoading(true)
            .screenMargins()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDisabled(true)
    }
}
