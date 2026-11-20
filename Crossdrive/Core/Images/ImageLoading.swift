import DataLayer
import ImageIO
import UIKit

/// Downloads a photo and decodes it at the size it will be shown. The trip
/// detail screen uses it to have its main photo ready before it appears.
protocol ImageLoading: Sendable {
    /// `nil` when the photo cannot be loaded. Never throws; a caller that was
    /// cancelled simply gets `nil` back.
    func image(for url: URL, maxPixels: Int) async -> UIImage?
}

/// Loads photos through the app's `HTTPClient`, like every other request, so
/// the client's rules apply: HTTPS only, and the API's headers and bearer token
/// go only to the API's own host, never to a photo host.
///
/// Decoded photos are kept in a small bounded memory cache owned by this
/// instance, so going back to a trip does not download it again.
///
/// `@unchecked Sendable` is safe here: every property is a `let`, and
/// `NSCache` is documented as safe to use from any thread.
final class HTTPImageLoader: ImageLoading, @unchecked Sendable {
    private let client: any HTTPClient
    private let cache = NSCache<NSString, UIImage>()

    init(client: any HTTPClient) {
        self.client = client
        cache.countLimit = 8
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    @concurrent
    func image(for url: URL, maxPixels: Int) async -> UIImage? {
        guard maxPixels > 0 else { return nil }
        let key = "\(url.absoluteString)#\(maxPixels)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let response = try? await client.send(
            .get(url.absoluteString, headers: ["Accept": "image/*"])
        ), !Task.isCancelled,
        let image = ImageDownsampler.image(from: response.data, maxPixels: maxPixels)
        else { return nil }
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }
}

/// Loads photos straight from the network, for previews and `-stub-api` runs,
/// where the stub client has no photos to give. Not used in the released app.
struct URLSessionImageLoader: ImageLoading {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    @concurrent
    func image(for url: URL, maxPixels: Int) async -> UIImage? {
        guard maxPixels > 0,
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse).map({ (200 ..< 300).contains($0.statusCode) }) ?? true,
              !Task.isCancelled
        else { return nil }
        return ImageDownsampler.image(from: data, maxPixels: maxPixels)
    }
}

/// Decodes straight to the display size with ImageIO, so a large photo never
/// sits in memory at full resolution.
enum ImageDownsampler {
    /// The longest side in pixels for a view of `size` on a screen of `scale`.
    static func maxPixels(for size: CGSize, scale: CGFloat) -> Int {
        Int((max(size.width, size.height) * scale).rounded(.up))
    }

    static func image(from data: Data, maxPixels: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
