import SwiftUI

/// Loads an image file from disk off the main thread and displays it via
/// Core Graphics, so the same view works on iOS, macOS, and visionOS.
struct AsyncDiskImage: View {
    let url: URL
    var contentMode: ContentMode = .fit

    @State private var cgImage: CGImage?

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
        .task(id: url) {
            cgImage = await Self.load(url)
        }
    }

    private static func load(_ url: URL) async -> CGImage? {
        await Task.detached {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return ImageProcessing.decode(data)
        }.value
    }
}
