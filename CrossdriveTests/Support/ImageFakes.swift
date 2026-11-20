@testable import Crossdrive
import UIKit

/// Returns a blank photo after the test's gate opens.
struct FakeImageLoader: ImageLoading {
    var beforeReturning: @Sendable () async -> Void = {}

    func image(for _: URL, maxPixels: Int) async -> UIImage? {
        await beforeReturning()
        let side = CGFloat(max(maxPixels, 1))
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in }
    }
}

/// Counts the pictures asked for and returns a blank one.
final class FakeSnapshotter: MapSnapshotting, @unchecked Sendable {
    private let lock = NSLock()
    private var asked = 0

    var count: Int {
        lock.withLock { asked }
    }

    func snapshot(
        of _: EventLocation,
        size: CGSize,
        scale _: CGFloat,
        isDark _: Bool
    ) async throws -> UIImage {
        lock.withLock { asked += 1 }
        return UIGraphicsImageRenderer(size: size).image { _ in }
    }
}
