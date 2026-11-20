import DesignSystem
import SwiftUI

extension Event {
    /// Made-up events with every part present, so the placeholder cards have
    /// the same shape as real ones. Their words are never read: they are redacted.
    static let placeholders: [Event] = (1 ... 2).map { number in
        Event(
            id: "placeholder-\(number)",
            kind: .trip,
            title: "Placeholder event title",
            place: "Placeholder place",
            startsAt: Date(timeIntervalSinceReferenceDate: 0),
            endsAt: Date(timeIntervalSinceReferenceDate: 172_800),
            travelTime: nil,
            fee: Money(amountMinor: 150_000, currency: "PHP"),
            capacity: 34,
            registeredCount: 20,
            isClosed: false
        )
    }
}

/// What the Events list shows while it loads: the real cards with made-up
/// words, redacted and shimmering, so nothing moves when the events arrive.
struct EventsSkeleton: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Event.placeholders) { event in
                    EventCard(event: event)
                }
            }
            // Grey and faint, like the canvas: card colours would read as real content.
            .saturation(0)
            .opacity(0.5)
            .dsLoading(true)
            .screenMargins()
            .padding(.bottom, theme.spacing.groupGap)
        }
        .scrollDisabled(true)
    }
}

#Preview("Loading") {
    EventsSkeleton()
        .background(Color(.systemGroupedBackground))
}
