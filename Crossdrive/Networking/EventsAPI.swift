import DataLayer
import Foundation

/// The events endpoint.
struct EventsAPI: Sendable {
    let client: any HTTPClient

    private let mapper = EventMapper()

    /// `GET /events` (public): the upcoming trips and camps. Events that can't
    /// be read are skipped rather than failing the whole list.
    func events() async throws -> [Event] {
        let dtos: [EventDTO] = try await client.send(.get("events"))
        return mapper.models(from: dtos)
    }

    /// `GET /events/{id}` (public): one event with its photos and roles. A
    /// missing or unreadable event is `NetworkError.notFound`.
    func event(id: Event.ID) async throws -> EventDetail {
        let dto: EventDetailDTO = try await client.send(.get("events/\(Self.pathSegment(id))"))
        guard let detail = mapper.detail(from: dto)
        else { throw NetworkError.notFound(message: nil) }
        return detail
    }

    /// A server-supplied id must not be able to add path segments.
    private static func pathSegment(_ id: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        return id.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}
