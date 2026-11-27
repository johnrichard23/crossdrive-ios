import DataLayer
import Foundation

/// The trips the signed-in person joined, their packing ticks and reminder.
struct MyTripsAPI: Sendable {
    let client: any HTTPClient

    private let mapper = MyTripMapper()

    /// `GET /me/trips` (signed in): every trip the person joined, soonest first.
    func trips() async throws -> [MyTrip] {
        let dtos: [MyTripDTO] = try await client.send(.get("me/trips"))
        return mapper.trips(from: dtos)
    }

    /// `PUT /me/registrations/{id}/packed/{itemId}`: ticks or clears one item.
    func setPacked(_ packed: Bool, item: MyTrip.BringItem.ID, registration: String) async throws {
        _ = try await client.send(
            .put(
                "me/registrations/\(path(registration))/packed/\(path(item))",
                body: ["packed": packed]
            )
        )
    }

    /// `PUT /me/registrations/{id}/reminder`: turns the night-before push on or off.
    func setReminder(_ isOn: Bool, registration: String) async throws {
        _ = try await client.send(
            .put("me/registrations/\(path(registration))/reminder", body: ["on": isOn])
        )
    }

    private func path(_ id: String) -> String {
        EventsAPI.pathSegment(id)
    }
}
