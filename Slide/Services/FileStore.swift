import Foundation
import UniformTypeIdentifiers

struct SavedImage {
    let imageFileName: String
    let thumbnailFileName: String
}

/// Stores image bytes as files in Documents/slides (+ thumbnails in
/// Documents/thumbs); SwiftData only ever holds the filenames. Pure
/// file-system I/O with no shared mutable state, so it's `nonisolated` and
/// freely callable from the main actor, background tasks, and OCR alike.
nonisolated struct FileStore {
    static let shared = FileStore()
    private let fm = FileManager.default
    private var docs: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    var slidesDir: URL { docs.appendingPathComponent("slides", isDirectory: true) }
    var thumbsDir: URL { docs.appendingPathComponent("thumbs", isDirectory: true) }

    func ensureDirs() {
        for d in [slidesDir, thumbsDir] {
            try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        }
    }

    /// `originalData` is the raw capture/import bytes (HEIC from the camera by default,
    /// or a re-encoded scanned page). Decodes once and reuses the CGImage for both the
    /// full-size save and the thumbnail.
    func save(originalData: Data, format: ImageFormat, jpegQuality: Double, maxLongEdge: Int) throws -> SavedImage {
        ensureDirs()
        let id = UUID().uuidString
        let imageName: String
        let decoded = ImageProcessing.decode(originalData)

        switch format {
        case .heicOriginal:
            imageName = "\(id).heic"
            if maxLongEdge > 0, let decoded {
                let resized = ImageProcessing.resized(decoded, maxLongEdge: CGFloat(maxLongEdge))
                let heic = try ImageProcessing.encodeHEIC(resized)
                try heic.write(to: slidesDir.appendingPathComponent(imageName))
            } else {
                try originalData.write(to: slidesDir.appendingPathComponent(imageName))
            }
        case .jpegCompressed:
            guard let decoded else { throw ImageProcessing.ProcessingError.decodeFailed }
            let resized = maxLongEdge > 0 ? ImageProcessing.resized(decoded, maxLongEdge: CGFloat(maxLongEdge)) : decoded
            let jpeg = try ImageProcessing.encodeJPEG(resized, quality: jpegQuality)
            imageName = "\(id).jpg"
            try jpeg.write(to: slidesDir.appendingPathComponent(imageName))
        }

        // Thumbnail: always JPEG, ~400px long edge.
        let thumbName = "\(id)_t.jpg"
        if let decoded {
            let thumb = ImageProcessing.resized(decoded, maxLongEdge: 400)
            if let thumbData = try? ImageProcessing.encodeJPEG(thumb, quality: 0.7) {
                try thumbData.write(to: thumbsDir.appendingPathComponent(thumbName))
            }
        }

        return SavedImage(imageFileName: imageName, thumbnailFileName: thumbName)
    }

    func imageURL(_ name: String) -> URL { slidesDir.appendingPathComponent(name) }
    func thumbURL(_ name: String) -> URL { thumbsDir.appendingPathComponent(name) }

    func delete(imageFileName: String, thumbnailFileName: String?) {
        try? fm.removeItem(at: imageURL(imageFileName))
        if let t = thumbnailFileName { try? fm.removeItem(at: thumbURL(t)) }
    }
}
