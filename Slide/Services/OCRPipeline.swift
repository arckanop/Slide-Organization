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
    private var saveTask: Task<Void, Never>?

    func process(slide: Slide, context: ModelContext) {
        pendingIDs.insert(slide.id)
        let url = FileStore.shared.imageURL(slide.imageFileName)
        let slideID = slide.id
        Task {
            defer { pendingIDs.remove(slideID) }
            let text = await Self.recognizeText(at: url)
            // The slide may have been deleted while OCR was running; writing to
            // (or saving) an invalidated model object would corrupt the context.
            guard slide.modelContext != nil else { return }
            slide.ocrText = text
            scheduleSave(context: context)
        }
    }

    /// A capture batch finishes OCR on several slides in close succession;
    /// without coalescing, each one would trigger its own SwiftData save.
    /// Debounce so a burst of completions collapses into a single save.
    private func scheduleSave(context: ModelContext) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            try? context.save()
        }
    }

    nonisolated private static func recognizeText(at url: URL) async -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return await OCRService().recognize(imageData: data)
    }
}
