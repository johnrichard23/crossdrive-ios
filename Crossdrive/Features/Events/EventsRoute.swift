/// Where the Events stack can go.
enum EventsRoute: Hashable {
    case detail(Event.ID)
    /// A trip the person joined, from the saved copy.
    case myTrip(Event.ID)
}
