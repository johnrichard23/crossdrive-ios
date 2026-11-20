import Foundation

/// The only place `MinistryDTO` and `Ministry` meet. Ministries are read-only,
/// so there is no way back to a DTO. A ministry that can't be read is dropped.
struct MinistryMapper: Sendable {
    func model(from dto: MinistryDTO) -> Ministry? {
        guard let id = dto.id, !id.isEmpty, let name = dto.name, !name.isEmpty else { return nil }
        return Ministry(
            id: id,
            name: name,
            schedule: dto.schedule,
            place: dto.place,
            summary: dto.summary ?? "",
            imageURL: dto.imageURL.flatMap(URL.init(string:))
        )
    }

    func models(from dtos: [MinistryDTO]) -> [Ministry] {
        dtos.compactMap(model)
    }

    /// The detail screen's model. `nil` when the ministry itself can't be read.
    /// Photos, updates, prayer and need that can't be read are left out.
    func detail(from dto: MinistryDetailDTO) -> MinistryDetail? {
        guard let ministry = dto.ministry.flatMap(model) else { return nil }
        return MinistryDetail(
            ministry: ministry,
            photos: (dto.photos ?? []).compactMap(photo),
            updates: (dto.updates ?? []).compactMap(update),
            prayer: dto.prayer.flatMap(prayer),
            need: dto.need.flatMap(need)
        )
    }

    private func photo(from dto: MinistryDetailDTO.PhotoDTO) -> MinistryPhoto? {
        guard let url = dto.url.flatMap(URL.init(string:)) else { return nil }
        return MinistryPhoto(url: url, caption: dto.caption ?? "")
    }

    private func update(from dto: MinistryDetailDTO.UpdateDTO) -> MinistryUpdate? {
        guard let id = dto.id, !id.isEmpty, let text = dto.text, !text.isEmpty else { return nil }
        return MinistryUpdate(
            id: id,
            text: text,
            postedAt: EventMapper.date(dto.postedAt),
            imageURL: dto.imageURL.flatMap(URL.init(string:))
        )
    }

    private func prayer(from dto: MinistryDetailDTO.PrayerDTO) -> HomePrayer? {
        guard let id = dto.id, !id.isEmpty, let body = dto.body, !body.isEmpty else { return nil }
        return HomePrayer(id: id, body: body, prayedCount: dto.prayedCount ?? 0)
    }

    private func need(from dto: MinistryDetailDTO.NeedDTO) -> MinistryNeed? {
        let events = EventMapper()
        guard let title = dto.title, !title.isEmpty,
              let raised = dto.raised.flatMap(events.money),
              let goal = dto.goal.flatMap(events.money)
        else { return nil }
        return MinistryNeed(title: title, raised: raised, goal: goal)
    }
}
