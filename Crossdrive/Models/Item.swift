/// The sample feature's model. Delete with the rest of the Sample feature.
struct Item: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var summary: String
    var isFavorite: Bool
}
