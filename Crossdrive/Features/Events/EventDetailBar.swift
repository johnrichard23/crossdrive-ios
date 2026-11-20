import DesignSystem
import SwiftUI

/// The pinned bar: price and note on the left, one action on the right. What it
/// offers depends on the trip and on whether the person is going.
struct EventPinnedBar: View {
    let detail: EventDetail
    let onRegister: () -> Void
    let onOpenTrip: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let content = Self.content(for: detail)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        return layout {
            VStack(alignment: .leading, spacing: 0) {
                Text(content.title).textRole(.title3, emphasized: true)
                if let note = content.note {
                    Text(note)
                        .textRole(.footnote)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
            if let action = content.action {
                Button(action.title, action: action.isOpenTrip ? onOpenTrip : onRegister)
                    .buttonStyle(.ds(.primary))
            }
        }
        .screenMargins()
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }

    struct Content {
        var title: String
        var note: String?
        var action: (title: LocalizedStringKey, isOpenTrip: Bool)?
    }

    static func content(for detail: EventDetail) -> Content {
        let event = detail.event
        let price = event.fee?.formatted ?? "Free"
        switch detail.bar {
        case .register:
            return Content(title: price, note: event.payBeforeLabel, action: ("Register", false))
        case .full:
            return Content(
                title: "Trip is full",
                note: "We'll message you if a slot opens",
                action: ("Join the waitlist", false)
            )
        case .waitlisted:
            return Content(
                title: "You're on the waitlist",
                note: "We'll message you if a slot opens",
                action: nil
            )
        case .closed:
            return Content(title: "Registration closed", note: nil, action: nil)
        case let .going(paid, _):
            return Content(
                title: price,
                note: paid ? "Paid" : "Not paid yet",
                action: ("Open my trip", true)
            )
        }
    }
}
