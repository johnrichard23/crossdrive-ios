import Foundation

/// The only place `HomeDTO` and `HomeSummary` meet. Home is read-only, so
/// there is no way back to a DTO. A part that can't be read is dropped and the
/// rest of Home still shows.
struct HomeMapper: Sendable {
    private let events = EventMapper()

    func model(from dto: HomeDTO) -> HomeSummary {
        HomeSummary(
            nextEvent: dto.nextEvent.flatMap(events.model),
            prayerPoint: dto.prayerPoint.flatMap(prayer),
            latestStory: dto.latestStory.flatMap(story)
        )
    }

    private func prayer(from dto: HomeDTO.PrayerDTO) -> HomePrayer? {
        guard let id = dto.id, !id.isEmpty, let body = dto.body, !body.isEmpty else { return nil }
        return HomePrayer(id: id, body: body, prayedCount: dto.prayedCount ?? 0)
    }

    private func story(from dto: HomeDTO.StoryDTO) -> HomeStory? {
        guard let id = dto.id, !id.isEmpty, let title = dto.title, !title.isEmpty else {
            return nil
        }
        return HomeStory(
            id: id,
            title: title,
            summary: dto.summary ?? "",
            imageURL: dto.imageURL.flatMap(URL.init(string:))
        )
    }
}
