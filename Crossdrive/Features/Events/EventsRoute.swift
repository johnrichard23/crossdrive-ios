/// Where the Events stack can go.
enum EventsRoute: Hashable {
    case detail(Event.ID)
    /// A trip the person joined, from the saved copy.
    case myTrip(Event.ID)
    /// That trip's schedule, day by day.
    case schedule(Event.ID)
    /// One activity on that schedule.
    case activity(Event.ID, MyTrip.ScheduleItem.ID)
}
