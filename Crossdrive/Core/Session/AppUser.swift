/// The signed-in person, as far as the app shell needs to know. A project
/// adds the fields its screens use.
struct AppUser: Sendable, Equatable, Codable {
    let id: String
    var name: String?
}
