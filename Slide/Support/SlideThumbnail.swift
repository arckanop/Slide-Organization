import SwiftUI

/// Shared thumbnail used in the Classes grid, Search results, and Home's
/// recent strip — shows a tiny spinner while OCR is still running.
struct SlideThumbnail: View {
    let slide: Slide
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncDiskImage(url: url, contentMode: contentMode)
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
