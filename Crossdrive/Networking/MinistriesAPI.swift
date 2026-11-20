import DataLayer
import Foundation

/// The ministries endpoint.
struct MinistriesAPI: Sendable {
    let client: any HTTPClient

    private let mapper = MinistryMapper()

    /// `GET /ministries` (public): every ministry, in the order the admins set.
    /// Ministries that can't be read are skipped rather than failing the list.
    func ministries() async throws -> [Ministry] {
        let dtos: [MinistryDTO] = try await client.send(.get("ministries"))
        return mapper.models(from: dtos)
    }

    /// `GET /ministries/{id}` (public): one ministry with its photos, updates,
    /// prayer point and need. A missing or unreadable ministry is
    /// `NetworkError.notFound`.
    func ministry(id: Ministry.ID) async throws -> MinistryDetail {
        let dto: MinistryDetailDTO = try await client.send(
            .get("ministries/\(Self.pathSegment(id))")
        )
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
