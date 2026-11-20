import DesignSystem

/// The icon for a role or a covered item. The trip names it with a key; a key
/// the app does not know shows the people icon instead of nothing.
enum EventIcon {
    static func source(for key: String?) -> DSIcon.Source {
        switch key {
        case "kids": .bible
        case "film": .video
        case "logistics": .mapPin
        case "boat": .boat
        case "meals", "cooking": .meals
        case "stay": .stay
        case "van": .van
        case "health": .health
        default: .people
        }
    }
}
