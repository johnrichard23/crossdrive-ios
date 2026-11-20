import Foundation

struct HomeMapper: Sendable {
    private let events = EventMapper()

    func model(from dto: HomeDTO) -> HomeSummary {
        HomeSummary(
            trip: dto.nextTrip.flatMap(trip),
            latestStory: dto.latestStory.flatMap(story)
        )
    }

    private func trip(from dto: HomeTripDTO) -> HomeTrip? {
        guard let event = dto.event.flatMap(events.model) else { return nil }
        let registration = dto.registration.flatMap(events.registration)
        return HomeTrip(
            event: event,
            fromPlace: dto.fromPlace.flatMap { $0.isEmpty ? nil : $0 },
            registration: registration,
            // The meeting point is for people who are going, whatever the server sent.
            meetup: registration?.status == .going ? dto.meetup.flatMap(events.meetup) : nil
        )
    }

    private func story(from dto: HomeStoryDTO) -> HomeStory? {
        // Photos of children need the family's consent before the app shows them.
        guard dto.hasConsent == true,
              let id = dto.id, !id.isEmpty,
              let title = dto.title, !title.isEmpty
        else { return nil }
        return HomeStory(
            id: id,
            title: title,
            quote: dto.quote ?? title,
            madeBy: dto.madeBy.flatMap { $0.isEmpty ? nil : $0 },
            imageURL: dto.imageURL.flatMap(URL.init(string:)),
            filmURL: dto.filmURL.flatMap(URL.init(string:))
                .flatMap { $0.scheme == "https" ? $0 : nil }
        )
    }
}
