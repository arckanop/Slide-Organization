import SwiftData
import Foundation
#if os(iOS)
import UIKit
#endif

/// Outcome of a `CaptureFlow.commit` call, so callers can tell the user when
/// some (but not all) pages failed to save instead of failing silently.
struct CaptureCommitResult {
    let savedCount: Int
    let failedCount: Int
}

/// Shared commit path for both capture modes (and import, Phase 3): turns raw
/// page bytes into saved files + `Slide` records attached to `target`.
@MainActor
enum CaptureFlow {
    @discardableResult
    static func commit(
        pages: [Data],
        to target: ClassSubject,
        sessionTitle: String? = nil,
        captureDate: Date = Date(),
        context: ModelContext
    ) -> CaptureCommitResult {
        let format = AppStorageSnapshot.imageFormat
        let quality = AppStorageSnapshot.jpegQuality
        let maxLongEdge = AppStorageSnapshot.maxLongEdge
        var savedCount = 0
        var failedCount = 0

        for data in pages {
            guard let saved = try? FileStore.shared.save(
                originalData: data, format: format, jpegQuality: quality, maxLongEdge: maxLongEdge
            ) else {
                failedCount += 1
                continue
            }

            let slide = Slide(imageFileName: saved.imageFileName, subject: target, captureDate: captureDate)
            slide.thumbnailFileName = saved.thumbnailFileName
            slide.sessionTitle = sessionTitle
            context.insert(slide)
            OCRPipeline.shared.process(slide: slide, context: context)
            savedCount += 1
        }
        try? context.save()

        #if os(iOS)
        if savedCount > 0 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif

        return CaptureCommitResult(savedCount: savedCount, failedCount: failedCount)
    }
}
