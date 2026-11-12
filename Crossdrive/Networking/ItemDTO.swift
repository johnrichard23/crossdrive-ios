/// What the server sends for an item. Every field the server may leave out is
/// optional; `ItemMapper` decides the defaults.
struct ItemDTO: Codable, Sendable {
    var id: String?
    var title: String?
    var summary: String?
    var isFavorite: Bool?
}
