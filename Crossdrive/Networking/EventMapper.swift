import Foundation

/// The only place `EventDTO` and `Event` meet. Events are read-only for now, so
/// there is no way back to a DTO. An event that can't be read is dropped.
struct EventMapper: Sendable {
    func model(from dto: EventDTO) -> Event? {
        guard let id = dto.id, !id.isEmpty,
              let title = dto.title, !title.isEmpty,
              let startsAt = Self.date(dto.startsAt)
        else { return nil }
        return Event(
            id: id,
            kind: dto.kind.flatMap(EventKind.init(rawValue:)) ?? .trip,
            title: title,
            place: dto.place,
            startsAt: startsAt,
            endsAt: Self.date(dto.endsAt),
            travelTime: dto.travelTime,
            fee: dto.fee.flatMap(money),
            capacity: dto.capacity,
            registeredCount: dto.registeredCount ?? 0,
            isClosed: dto.status == "full" || dto.status == "closed",
            isFull: dto.status == "full",
            heroImageURL: dto.heroImageURL.flatMap(URL.init(string:))
        )
    }

    /// The readable events, soonest first.
    func models(from dtos: [EventDTO]) -> [Event] {
        dtos.compactMap(model).sorted { $0.startsAt < $1.startsAt }
    }

    /// The detail screen's model. `nil` when the event itself can't be read.
    func detail(from dto: EventDetailDTO) -> EventDetail? {
        guard let event = dto.event.flatMap(model) else { return nil }
        let registration = dto.registration.flatMap(registration)
        return EventDetail(
            event: event,
            summary: dto.summary ?? "",
            background: dto.background ?? "",
            photoURLs: (dto.photos ?? []).compactMap(URL.init(string:)),
            roles: (dto.roles ?? []).compactMap(role),
            peopleCount: dto.people,
            location: dto.location.flatMap(location),
            covers: (dto.covers ?? []).compactMap(cover),
            notCovered: dto.notCovered.flatMap { $0.isEmpty ? nil : $0 },
            bringList: (dto.bringList ?? []).filter { !$0.isEmpty },
            registration: registration,
            // The meeting point is for people who are going, whatever the server sent.
            meetup: registration?.status == .going ? dto.meetup.flatMap(meetup) : nil,
            waiver: dto.waiver.flatMap(waiver),
            pay: dto.pay.flatMap(pay)
        )
    }

    private func role(_ dto: EventDetailDTO.RoleDTO) -> EventRole? {
        guard let id = dto.id, !id.isEmpty, let name = dto.name, !name.isEmpty else { return nil }
        return EventRole(
            id: id,
            name: name,
            summary: dto.summary ?? "",
            iconKey: dto.icon,
            slotsLeft: dto.slotsLeft.map { max($0, 0) }
        )
    }

    private func waiver(_ dto: EventDetailDTO.WaiverDTO) -> EventWaiver? {
        guard let text = dto.text, !text.isEmpty else { return nil }
        return EventWaiver(text: text, pdfURL: dto.pdfUrl.flatMap(Self.httpsURL))
    }

    /// The QR code must come over HTTPS; anything else is dropped rather than shown.
    private func pay(_ dto: EventDetailDTO.PayDTO) -> EventPay? {
        let qrURL = dto.qrUrl.flatMap(Self.httpsURL)
        let gcash = dto.gcash.flatMap { $0.isEmpty ? nil : $0 }
        guard qrURL != nil || gcash != nil else { return nil }
        return EventPay(qrURL: qrURL, gcashNumber: gcash)
    }

    private static func httpsURL(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    private func cover(_ dto: EventDetailDTO.CoverDTO) -> EventCover? {
        guard let id = dto.id, !id.isEmpty, let name = dto.name, !name.isEmpty else { return nil }
        return EventCover(id: id, name: name, iconKey: dto.icon)
    }

    private func location(_ dto: EventDetailDTO.LocationDTO) -> EventLocation? {
        guard let name = dto.name, !name.isEmpty,
              let latitude = dto.latitude, (-90 ... 90).contains(latitude),
              let longitude = dto.longitude, (-180 ... 180).contains(longitude)
        else { return nil }
        return EventLocation(
            name: name,
            area: dto.area,
            latitude: latitude,
            longitude: longitude
        )
    }

    func registration(_ dto: EventDetailDTO.MeDTO) -> EventRegistration? {
        let status: EventRegistration.Status
        switch dto.status {
        case "going": status = .going
        case "waitlisted": status = .waitlisted
        default: return nil
        }
        return EventRegistration(
            status: status,
            waiverSigned: dto.waiverSigned ?? false,
            isPaid: dto.paid ?? false
        )
    }

    func meetup(_ dto: EventDetailDTO.MeetupDTO) -> EventMeetup? {
        guard let point = dto.point, !point.isEmpty, let time = dto.time, !time.isEmpty
        else { return nil }
        return EventMeetup(point: point, time: time)
    }

    func money(from dto: EventDTO.MoneyDTO) -> Money? {
        guard let amount = dto.amountMinor else { return nil }
        return Money(amountMinor: amount, currency: dto.currency ?? "PHP")
    }

    static func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        return try? Date(string, strategy: .iso8601)
    }
}
