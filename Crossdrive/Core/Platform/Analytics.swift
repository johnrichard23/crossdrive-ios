/// Every event the app reports, in one place. Names and fields live here, not
/// at the call sites, so the list can be reviewed and an analytics vendor
/// mapped to it once.
enum AnalyticsEvent: Equatable, Sendable {
    case appOpened
    case signedIn
    case signedOut
    case onboardingFinished
    case deepLinkOpened
    case pushTapped
}

/// Where events go. The default drops them; a project adds its vendor behind
/// this protocol. Events carry no personal data.
protocol Analytics: Sendable {
    func track(_ event: AnalyticsEvent)
}

struct NoAnalytics: Analytics {
    func track(_: AnalyticsEvent) {}
}
