import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

/// Decode/resize/encode helpers built on Core Graphics + ImageIO instead of
/// UIImage/NSImage, so the same code runs unmodified on iOS, macOS, and visionOS.
/// Pure functions with no shared state, so it's `nonisolated` and callable
/// from any isolation domain (OCR, capture, PDF export all run it off the main actor).
nonisolated enum ImageProcessing {
    enum ProcessingError: Error {
        case decodeFailed
        case encodeFailed
    }

    static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Returns a new CGImage scaled so its longer edge is `maxLongEdge` pixels.
    /// Returns the original image unchanged if it's already smaller.
    static func resized(_ image: CGImage, maxLongEdge: CGFloat) -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let longEdge = max(width, height)
        guard longEdge > maxLongEdge, maxLongEdge > 0 else { return image }

        let scale = maxLongEdge / longEdge
        let newWidth = max(1, Int((width * scale).rounded()))
        let newHeight = max(1, Int((height * scale).rounded()))

        guard let colorSpace = image.colorSpace,
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return image }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? image
    }

    static func encodeHEIC(_ image: CGImage) throws -> Data {
        try encode(image, type: .heic, quality: 1.0)
    }

    static func encodeJPEG(_ image: CGImage, quality: Double) throws -> Data {
        try encode(image, type: .jpeg, quality: quality)
    }

    private static func encode(_ image: CGImage, type: UTType, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            throw ProcessingError.encodeFailed
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ProcessingError.encodeFailed }
        return data as Data
    }
}
