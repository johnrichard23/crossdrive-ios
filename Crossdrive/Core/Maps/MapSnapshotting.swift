import MapKit
import UIKit

/// Draws a still picture of a place. A picture, not a live map: it costs one
/// image in memory, needs no location permission and stops when its task is
/// cancelled.
protocol MapSnapshotting: Sendable {
    func snapshot(
        of location: EventLocation,
        size: CGSize,
        scale: CGFloat,
        isDark: Bool
    ) async throws -> UIImage
}

struct AppleMapSnapshotter: MapSnapshotting {
    /// How much ground the picture shows, side to side, in metres.
    private let span: CLLocationDistance = 6000

    func snapshot(
        of location: EventLocation,
        size: CGSize,
        scale: CGFloat,
        isDark: Bool
    ) async throws -> UIImage {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            ),
            latitudinalMeters: span,
            longitudinalMeters: span
        )
        options.size = size
        options.scale = scale
        options.traitCollection = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
        options.showsBuildings = false

        nonisolated(unsafe) let snapshotter = MKMapSnapshotter(options: options)
        let pending = PendingSnapshot()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending.begin(continuation)
                snapshotter.start { snapshot, error in
                    if let image = snapshot?.image {
                        pending.finish(.success(image))
                    } else {
                        pending.finish(.failure(error ?? CancellationError()))
                    }
                }
            }
        } onCancel: {
            snapshotter.cancel()
            // MapKit may never call back after a cancel; end the wait ourselves so the
            // task, the view model and the snapshotter are released.
            pending.finish(.failure(CancellationError()))
        }
    }
}

/// Resumes a waiting caller exactly once, whichever happens first: the picture
/// arrives, or the task is cancelled (even before the wait has begun).
private final class PendingSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<UIImage, any Error>?
    private var result: Result<UIImage, any Error>?
    private var isFinished = false

    func begin(_ continuation: CheckedContinuation<UIImage, any Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func finish(_ outcome: Result<UIImage, any Error>) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        if let continuation {
            self.continuation = nil
            lock.unlock()
            continuation.resume(with: outcome)
        } else {
            result = outcome
            lock.unlock()
        }
    }
}
