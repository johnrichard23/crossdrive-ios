import DataLayer

/// Home's endpoint.
struct HomeAPI: Sendable {
    let client: any HTTPClient

    private let mapper = HomeMapper()

    /// `GET /home` (public): the next event with the caller's place on it (and
    /// the meeting point only when going) and the latest story, in one reply.
    /// Prayer content is not part of Home.
    func home() async throws -> HomeSummary {
        let dto: HomeDTO = try await client.send(.get("home"))
        return mapper.model(from: dto)
    }
}
