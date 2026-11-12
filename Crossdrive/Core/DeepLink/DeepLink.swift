/// Where a link or a push notification wants the app to go. Add a case here,
/// a rule in `DeepLinkRouter`, and a branch in `AppCoordinator` for each place.
enum DeepLink: Hashable, Sendable {
    case item(Item.ID)
}
