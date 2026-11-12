import Foundation

/// Holds a fake request until the test lets it go, so a test controls the
/// order of events without sleeping.
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Suspends until `open()` has been called (returns at once if it already was).
    func wait() async {
        if isOpen {
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

/// Numbers calls from any thread: 1 for the first, 2 for the second.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }
}

/// Collects values from any thread, in order.
final class Recorder<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Value] = []

    var values: [Value] {
        lock.withLock { stored }
    }

    func add(_ value: Value) {
        lock.withLock { stored.append(value) }
    }
}

/// A clock the test moves by hand.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_000_000)) {
        current = start
    }

    var now: Date {
        lock.withLock { current }
    }

    func advance(by seconds: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(seconds) }
    }
}

/// Answers `URLSession` requests from a closure, for tests that need a real
/// `URLSessionHTTPClient` (interceptors, redirects) but no network.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    /// Returns the status and body for each request. Set before the request.
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (status: Int, body: Data))?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let reply = handler(request)
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: reply.status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
