@preconcurrency import Vision
import CoreGraphics
import Foundation

/// English + numbers only — Apple's on-device Vision text recognizer has no
/// Thai support. Thai slides stay searchable via sessionTitle/note instead.
struct OCRService {
    nonisolated func recognize(imageData: Data) async -> String? {
        guard let cgImage = ImageProcessing.decode(imageData) else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // English only — Vision has no Thai. Intersect with what the OS
            // actually supports so we never set an unsupported language.
            let wanted = ["en-US"]
            let supported = (try? request.supportedRecognitionLanguages()) ?? ["en-US"]
            request.recognitionLanguages = wanted.filter(supported.contains)
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .utility).async {
                try? handler.perform([request])
            }
        }
    }
}
