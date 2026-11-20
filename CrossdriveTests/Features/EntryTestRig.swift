@testable import Crossdrive
import DataLayer
import XCTest

struct EntryRig {
    var viewModel: EntryViewModel
    var requests: Recorder<String>
    var signIns: Recorder<String>
}

/// `handler` answers the account endpoints; `signIn` is the coordinator's sign-in.
@MainActor
func makeEntryRig(
    trip: GateTrip? = nil,
    handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse = { _ in .json("{}") },
    signIn: @escaping @Sendable (Credentials) async throws -> Void = { _ in }
) -> EntryRig {
    let requests = Recorder<String>()
    let signIns = Recorder<String>()
    let client = StubHTTPClient { endpoint in
        requests.add(endpoint.path)
        return try await handler(endpoint)
    }
    let viewModel = EntryViewModel(
        trip: trip,
        accountAPI: AccountAPI(client: client),
        imageLoader: FakeImageLoader(),
        signIn: { credentials in
            signIns.add(credentials.email)
            try await signIn(credentials)
        }
    )
    return EntryRig(viewModel: viewModel, requests: requests, signIns: signIns)
}
