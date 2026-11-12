/// Whether the device has a network connection, as it changes.
///
/// This tells you before a request fails; `error.isOffline` tells you after.
/// Having a connection doesn't mean the server is reachable.
protocol Connectivity: Sendable {
    /// `true` when online. The first value is the current state.
    var updates: AsyncStream<Bool> { get }
}
