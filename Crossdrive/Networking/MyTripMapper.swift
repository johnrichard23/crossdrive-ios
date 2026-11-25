import Foundation

/// The only place `MyTripDTO` and `MyTrip` meet. A trip missing its ids, name,
/// dates or a known status is dropped; a missing optional part is left out.
struct MyTripMapper: Sendable {
    private let events = EventMapper()

    /// The readable trips, soonest first.
    func trips(from dtos: [MyTripDTO]) -> [MyTrip] {
        dtos.compactMap(trip).sorted { $0.event.startsAt < $1.event.startsAt }
    }

    private func trip(_ dto: MyTripDTO) -> MyTrip? {
        guard let registration = dto.registration,
              let registrationID = nonEmpty(registration.id),
              let status = registration.status.flatMap(MyTrip.Status.init(rawValue:)),
              let eventDTO = dto.event,
              let id = nonEmpty(eventDTO.id),
              let event = event(eventDTO)
        else { return nil }
        let bring = (dto.bring ?? []).compactMap(bringItem)
        return MyTrip(
            id: id,
            registrationID: registrationID,
            status: status,
            waiverSigned: registration.waiverSigned ?? false,
            paid: registration.paid ?? false,
            permit: registration.permit.flatMap(permit),
            event: event,
            meetup: dto.meetup.flatMap(meetup),
            lead: dto.lead.flatMap(person),
            team: dto.team.flatMap(team),
            schedule: dto.schedule.flatMap(schedule),
            bring: bring,
            packed: Set(dto.packed ?? []),
            remindNightBefore: dto.remindNightBefore ?? false
        )
    }

    private func event(_ dto: MyTripDTO.EventDTO) -> MyTrip.TripSummary? {
        guard let name = nonEmpty(dto.name),
              let startsAt = EventMapper.date(dto.startsAt),
              let endsAt = EventMapper.date(dto.endsAt)
        else { return nil }
        return MyTrip.TripSummary(
            kind: dto.kind.flatMap(EventKind.init(rawValue:)) ?? .trip,
            name: name,
            startsAt: startsAt,
            endsAt: endsAt,
            fee: dto.fee.flatMap(events.money),
            payBy: EventMapper.date(dto.payBy)
        )
    }

    private func meetup(_ dto: MyTripDTO.MeetupDTO) -> MyTrip.Meetup? {
        guard let point = nonEmpty(dto.point), let startsAt = EventMapper.date(dto.startsAt)
        else { return nil }
        return MyTrip.Meetup(
            point: point,
            startsAt: startsAt,
            latitude: dto.latitude,
            longitude: dto.longitude
        )
    }

    private func person(_ dto: MyTripDTO.PersonDTO) -> MyTrip.Lead? {
        guard let name = nonEmpty(dto.name) else { return nil }
        return MyTrip.Lead(name: name, phone: nonEmpty(dto.phone))
    }

    private func team(_ dto: MyTripDTO.TeamDTO) -> MyTrip.Team? {
        guard let id = nonEmpty(dto.id), let name = nonEmpty(dto.name) else { return nil }
        return MyTrip.Team(id: id, name: name)
    }

    private func permit(_ dto: MyTripDTO.PermitDTO) -> MyTrip.Permit? {
        guard let name = nonEmpty(dto.name) else { return nil }
        return MyTrip.Permit(name: name, signed: dto.signed ?? false)
    }

    private func bringItem(_ dto: MyTripDTO.BringDTO) -> MyTrip.BringItem? {
        guard let id = nonEmpty(dto.id), let title = nonEmpty(dto.title) else { return nil }
        return MyTrip.BringItem(id: id, title: title)
    }

    private func schedule(_ dto: MyTripDTO.ScheduleDTO) -> MyTrip.Schedule {
        MyTrip.Schedule(
            published: dto.published ?? false,
            updatedAt: EventMapper.date(dto.updatedAt),
            items: (dto.items ?? []).compactMap(item).sorted { $0.startsAt < $1.startsAt }
        )
    }

    private func item(_ dto: MyTripDTO.ItemDTO) -> MyTrip.ScheduleItem? {
        guard let id = nonEmpty(dto.id),
              let title = nonEmpty(dto.title),
              let startsAt = EventMapper.date(dto.startsAt)
        else { return nil }
        return MyTrip.ScheduleItem(
            id: id,
            startsAt: startsAt,
            endsAt: EventMapper.date(dto.endsAt),
            title: title,
            summary: nonEmpty(dto.summary),
            place: nonEmpty(dto.place),
            latitude: dto.latitude,
            longitude: dto.longitude,
            team: dto.team.flatMap(team),
            bring: nonEmpty(dto.bring),
            ask: dto.ask.flatMap(person),
            movedFrom: EventMapper.date(dto.movedFrom)
        )
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}
