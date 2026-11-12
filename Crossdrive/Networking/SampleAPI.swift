import DataLayer
import Foundation

/// The sample feature's endpoints: one function per endpoint, each saying
/// which request it sends.
struct SampleAPI: Sendable {
    let client: any HTTPClient

    private let mapper = ItemMapper()

    /// `GET /items`: every item, in the server's order. Items without an id
    /// are skipped rather than failing the whole list.
    func items() async throws -> [Item] {
        let dtos: [ItemDTO] = try await client.send(.get("items"))
        return try mapper.models(from: dtos, skipInvalid: true)
    }

    /// `PUT /items/{id}/favorite`: sets or clears the favourite mark.
    func setFavorite(_ isFavorite: Bool, forItem id: Item.ID) async throws {
        _ = try await client.send(
            .put(
                "items/\(Self.pathSegment(id))/favorite",
                body: FavoriteBody(isFavorite: isFavorite)
            )
        )
    }

    /// A server-supplied id must not be able to add path segments.
    private static func pathSegment(_ id: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        return id.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}

private struct FavoriteBody: Encodable {
    let isFavorite: Bool
}
