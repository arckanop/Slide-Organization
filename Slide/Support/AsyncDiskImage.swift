import SwiftUI

/// Loads an image file from disk off the main thread and displays it via
/// Core Graphics, so the same view works on iOS, macOS, and visionOS.
///
/// `maxPixelSize`, when set, decodes a downsampled thumbnail via ImageIO
/// instead of materializing the full bitmap — grid cells and unzoomed pager
/// pages never need a multi-megapixel image in memory. Decoded images are
/// kept in a shared cache so cells reappearing during scroll don't re-read
/// and re-decode from disk.
struct AsyncDiskImage: View {
    let url: URL
    var contentMode: ContentMode = .fit
    var maxPixelSize: CGFloat? = nil

    @State private var cgImage: CGImage?

    private static let cache = NSCache<NSString, CGImage>()

    var body: some View {
        Group {
            if let cgImage {
                Image(decorative: cgImage, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .task(id: CacheKey(url: url, maxPixelSize: maxPixelSize)) {
            let key = Self.cacheKey(url: url, maxPixelSize: maxPixelSize)
            if let cached = Self.cache.object(forKey: key) {
                cgImage = cached
                return
            }
            guard let loaded = await Self.load(url, maxPixelSize: maxPixelSize) else { return }
            Self.cache.setObject(loaded, forKey: key)
            cgImage = loaded
        }
    }

    private struct CacheKey: Hashable {
        let url: URL
        let maxPixelSize: CGFloat?
    }

    private static func cacheKey(url: URL, maxPixelSize: CGFloat?) -> NSString {
        "\(url.absoluteString)#\(maxPixelSize.map { Int($0) } ?? -1)" as NSString
    }

    private static func load(_ url: URL, maxPixelSize: CGFloat?) async -> CGImage? {
        await Task.detached {
            if let maxPixelSize {
                return ImageProcessing.thumbnail(contentsOf: url, maxPixelSize: maxPixelSize)
            }
            return ImageProcessing.decode(contentsOf: url)
        }.value
    }
}
