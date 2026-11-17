/// The peer tabs of the main screen, in tab-bar order.
enum MainTab: Hashable, CaseIterable {
    case home
    case events
    case ministries
    case pray
    case profile

    /// The tab's name in the tab bar and as its screen title.
    var title: String {
        switch self {
        case .home: "Home"
        case .events: "Events"
        case .ministries: "Ministries"
        case .pray: "Pray"
        case .profile: "Profile"
        }
    }

    /// The asset-catalog name of the tab's CrossDrive icon.
    var iconName: String {
        switch self {
        case .home: "Icons/home"
        case .events: "Icons/mission"
        case .ministries: "Icons/people"
        case .pray: "Icons/pray"
        case .profile: "Icons/user"
        }
    }
}
