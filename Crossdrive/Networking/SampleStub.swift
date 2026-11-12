import DataLayer
import Foundation

/// Canned server replies, so the app and its previews run with no backend.
/// Launch the Debug app with `-stub-api` to use them (the Xcode scheme does).
///
/// Sign in with any email and password, except the password `wrong`, which
/// is rejected, so the error state can be seen.
enum SampleStub {
    static let itemsJSON = """
    [
      {"id": "1", "title": "Coffee beans", "summary": "Whole bean, medium roast", "isFavorite": true},
      {"id": "2", "title": "Notebook", "summary": "Dot grid, A5"},
      {"id": "3", "title": "Desk lamp", "summary": "Warm light, dimmable"},
      {"id": "4", "title": "Water bottle", "summary": "Insulated, 750 ml"},
      {"id": "5", "title": "Headphones", "summary": "Over-ear, wired"}
    ]
    """

    static let signInJSON = """
    {"accessToken": "stub-access", "refreshToken": "stub-refresh", "expiresIn": 3600,
     "user": {"id": "stub-user", "name": "Sample User"}}
    """

    @Sendable
    static func handle(_ endpoint: Endpoint) async throws -> HTTPResponse {
        switch (endpoint.method, endpoint.path) {
        case (.get, "items"):
            return .json(itemsJSON)
        case (.post, "auth/sign-in"):
            let fields = endpoint.body.flatMap { try? JSONDecoder().decode(
                [String: String].self,
                from: $0
            ) }
            if fields?["password"] == "wrong" {
                return .json(#"{"message": "Incorrect email or password."}"#, status: 401)
            }
            return .json(signInJSON)
        case (.post, "auth/refresh"):
            return .json(#"{"accessToken": "stub-access-2", "expiresIn": 3600}"#)
        default:
            return .json("{}")
        }
    }
}
