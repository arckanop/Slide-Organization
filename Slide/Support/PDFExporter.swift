import PDFKit
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Renders a class's slides into a single date-ordered PDF for exam review.
/// Takes plain `(url, date)` pairs rather than `Slide` models so it can run
/// off the main actor without crossing a non-Sendable model type.
enum PDFExporter {
    nonisolated static func export(pages: [(url: URL, date: Date)], title: String) -> URL? {
        let sorted = pages.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return nil }

        let document = PDFDocument()
        var pageIndex = 0
        for page in sorted {
            guard let data = try? Data(contentsOf: page.url),
                  let cgImage = ImageProcessing.decode(data),
                  let pdfPage = pdfPage(from: cgImage)
            else { continue }
            document.insert(pdfPage, at: pageIndex)
            pageIndex += 1
        }
        guard document.pageCount > 0 else { return nil }

        let sanitizedTitle = title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitizedTitle).pdf")
        guard document.write(to: url) else { return nil }
        return url
    }

    nonisolated private static func pdfPage(from cgImage: CGImage) -> PDFPage? {
        #if os(macOS)
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #else
        let image = UIImage(cgImage: cgImage)
        #endif
        return PDFPage(image: image)
    }
}
