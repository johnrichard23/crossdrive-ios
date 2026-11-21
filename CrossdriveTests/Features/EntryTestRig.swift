@testable import Crossdrive
import DataLayer
import XCTest

struct EntryRig {
    var viewModel: EntryViewModel
    var requests: Recorder<String>
    var signIns: Recorder<String>
    var socialSignIns: Recorder<String>
}

/// `handler` answers the account endpoints; `signIn` is the coordinator's sign-in.
@MainActor
func makeEntryRig(
    trip: GateTrip? = nil,
    handler: @escaping @Sendable (Endpoint) async throws -> HTTPResponse = { _ in .json("{}") },
    facebook: any SocialSignInProviding = FakeSocialSignIn(),
    signIn: @escaping @Sendable (Credentials) async throws -> Void = { _ in },
    signInWithSocial: @escaping @Sendable (SocialCredential) async throws -> Void = { _ in }
) -> EntryRig {
    let requests = Recorder<String>()
    let signIns = Recorder<String>()
    let socialSignIns = Recorder<String>()
    let client = StubHTTPClient { endpoint in
        requests.add(endpoint.path)
        return try await handler(endpoint)
    }
    let viewModel = EntryViewModel(
        trip: trip,
        accountAPI: AccountAPI(client: client),
        imageLoader: FakeImageLoader(),
        facebook: facebook,
        signIn: { credentials in
            signIns.add(credentials.email)
            try await signIn(credentials)
        },
        signInWithSocial: { credential in
            socialSignIns.add(credential.token)
            try await signInWithSocial(credential)
        }
    )
    return EntryRig(
        viewModel: viewModel,
        requests: requests,
        signIns: signIns,
        socialSignIns: socialSignIns
    )
}
