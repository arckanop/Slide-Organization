#if os(iOS)
import SwiftUI
import VisionKit
import UIKit

/// Wraps `VNDocumentCameraViewController` — auto edge-detection, deskew, and
/// crop, with multi-page support in one session. Default capture mode.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onFinish: (_ pages: [Data]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onFinish: (_ pages: [Data]) -> Void
        private let onCancel: () -> Void

        init(onFinish: @escaping (_ pages: [Data]) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var pages: [Data] = []
            for index in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: index)
                if let cgImage = image.cgImage, let data = try? ImageProcessing.encodeHEIC(cgImage) {
                    pages.append(data)
                }
            }
            onFinish(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onCancel()
        }
    }
}
#endif
