import DataLayer

/// Home's endpoint.
struct HomeAPI: Sendable {
    let client: any HTTPClient

    private let mapper = HomeMapper()

    /// `GET /home` (public): the next event, today's prayer point and the
    /// latest story, in one reply.
    func home() async throws -> HomeSummary {
        let dto: HomeDTO = try await client.send(.get("home"))
        return mapper.model(from: dto)
    }
}
