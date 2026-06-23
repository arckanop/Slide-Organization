import SwiftUI

/// Shared thumbnail used in the Classes grid, Search results, and Home's
/// recent strip — shows a tiny spinner while OCR is still running.
struct SlideThumbnail: View {
    let slide: Slide
    var contentMode: ContentMode = .fill

    /// All current grid cells are well under 200pt; this comfortably covers
    /// retina scales without falling back to a full decode.
    private static let maxPixelSize: CGFloat = 480

    var body: some View {
        AsyncDiskImage(url: url, contentMode: contentMode, maxPixelSize: Self.maxPixelSize)
            .overlay(alignment: .bottomTrailing) {
                if OCRPipeline.shared.pendingIDs.contains(slide.id) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(4)
                        .background(.black.opacity(0.4), in: Circle())
                        .padding(4)
                }
            }
    }

    private var url: URL {
        if let thumb = slide.thumbnailFileName { return FileStore.shared.thumbURL(thumb) }
        return FileStore.shared.imageURL(slide.imageFileName)
    }
}
