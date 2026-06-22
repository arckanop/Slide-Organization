import SwiftData
import Foundation
import Observation

/// Runs OCR for newly saved slides in the background and writes the result
/// back on the main actor. `pendingIDs` lets views show a tiny "processing"
/// indicator without needing a separate persisted status field.
@MainActor
@Observable
final class OCRPipeline {
    static let shared = OCRPipeline()
    private init() {}

    private(set) var pendingIDs: Set<UUID> = []

    func process(slide: Slide, context: ModelContext) {
        pendingIDs.insert(slide.id)
        let url = FileStore.shared.imageURL(slide.imageFileName)
        let slideID = slide.id
        Task {
            let text = await Self.recognizeText(at: url)
            slide.ocrText = text
            try? context.save()
            pendingIDs.remove(slideID)
        }
    }

    nonisolated private static func recognizeText(at url: URL) async -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return await OCRService().recognize(imageData: data)
    }
}
