import DataLayer

/// `MyTripsAPI` as the repository's remote. There is no single-trip endpoint,
/// so one trip is read from the list.
struct MyTripsRemote: RemoteSource {
    let api: MyTripsAPI

    func fetchAll() async throws -> [MyTrip] {
        try await api.trips()
    }

    func fetch(id: String) async throws -> MyTrip {
        guard let trip = try await api.trips().first(where: { $0.id == id })
        else { throw NetworkError.notFound(message: nil) }
        return trip
    }
}
