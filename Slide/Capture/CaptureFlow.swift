import SwiftData
import Foundation
#if os(iOS)
import UIKit
#endif

/// Shared commit path for both capture modes (and import, Phase 3): turns raw
/// page bytes into saved files + `Slide` records attached to `target`.
@MainActor
enum CaptureFlow {
    static func commit(
        pages: [Data],
        to target: ClassSubject,
        sessionTitle: String? = nil,
        captureDate: Date = Date(),
        context: ModelContext
    ) {
        let format = AppStorageSnapshot.imageFormat
        let quality = AppStorageSnapshot.jpegQuality
        let maxLongEdge = AppStorageSnapshot.maxLongEdge
        var savedAny = false

        for data in pages {
            guard let saved = try? FileStore.shared.save(
                originalData: data, format: format, jpegQuality: quality, maxLongEdge: maxLongEdge
            ) else { continue }

            let slide = Slide(imageFileName: saved.imageFileName, subject: target, captureDate: captureDate)
            slide.thumbnailFileName = saved.thumbnailFileName
            slide.sessionTitle = sessionTitle
            context.insert(slide)
            OCRPipeline.shared.process(slide: slide, context: context)
            savedAny = true
        }
        try? context.save()

        #if os(iOS)
        if savedAny {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }
}
