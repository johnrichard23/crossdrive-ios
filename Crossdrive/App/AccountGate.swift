import SwiftUI

/// How a screen asks for an account without knowing about the coordinator:
///
///     @Environment(\.accountGate) private var accountGate
///     Button("Favorite") { accountGate { Task { await viewModel.favorite() } } }
///
/// Signed in (or in an app without optional accounts): the action runs now.
/// A guest in an app with optional accounts: the login gate opens, and the
/// action runs after they sign in.
struct AccountGate: Sendable {
    private let require: @MainActor (@escaping @MainActor () -> Void) -> Void

    init(_ require: @escaping @MainActor (@escaping @MainActor () -> Void) -> Void) {
        self.require = require
    }

    /// Runs the action at once. The default, for previews.
    static let open = AccountGate { $0() }

    @MainActor
    func callAsFunction(_ action: @escaping @MainActor () -> Void) {
        require(action)
    }
}

extension EnvironmentValues {
    @Entry var accountGate = AccountGate.open
}
