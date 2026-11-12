/// A connection the caller controls, for previews and tests.
actor FakeConnectivity: Connectivity {
    nonisolated let updates: AsyncStream<Bool>

    private let continuation: AsyncStream<Bool>.Continuation

    init() {
        (updates, continuation) = AsyncStream<Bool>.makeStream()
    }

    func send(_ isOnline: Bool) {
        continuation.yield(isOnline)
    }
}
