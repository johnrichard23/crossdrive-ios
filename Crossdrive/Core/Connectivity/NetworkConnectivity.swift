import Dispatch
import Network

/// The real thing, over `NWPathMonitor`. Each read of `updates` starts its own
/// monitor and stops it when the stream ends.
struct NetworkConnectivity: Connectivity {
    var updates: AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { continuation.yield($0.status == .satisfied) }
            continuation.onTermination = { _ in monitor.cancel() }
            // NWPathMonitor delivers on a dispatch queue; nothing else uses it.
            monitor.start(queue: DispatchQueue(label: "connectivity"))
        }
    }
}
