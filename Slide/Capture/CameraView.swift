#if os(iOS)
import SwiftUI
import AVFoundation
import UIKit

/// Normal rapid-multi-shot camera mode: stays open after each shot so the
/// user can fire off several slides before tapping Done.
struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var controller = CameraSessionController()
    @State private var capturedPages: [CapturedPage] = []

    var onFinish: (_ pages: [Data]) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: controller.session)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                if !capturedPages.isEmpty {
                    thumbnailStrip
                }
                shutterButton
                    .padding(.bottom, 32)
            }
        }
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
        .alert("Camera Access Needed", isPresented: $controller.permissionDenied) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Enable camera access in Settings to take photos of slides.")
        }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .foregroundStyle(.white)
            Spacer()
            if !capturedPages.isEmpty {
                Button("Done (\(capturedPages.count))") {
                    onFinish(capturedPages.map(\.data))
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            }
        }
        .padding()
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(capturedPages) { page in
                    Image(decorative: page.thumbnail, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 64)
        .padding(.bottom, 12)
    }

    private var shutterButton: some View {
        Button(action: capture) {
            Circle()
                .fill(.white)
                .frame(width: 72, height: 72)
                .overlay(Circle().strokeBorder(.black.opacity(0.2), lineWidth: 2))
        }
    }

    private func capture() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        controller.capturePhoto { data in
            guard let data, let cgImage = ImageProcessing.decode(data) else { return }
            let thumbnail = ImageProcessing.resized(cgImage, maxLongEdge: 160)
            capturedPages.append(CapturedPage(data: data, thumbnail: thumbnail))
        }
    }
}

private struct CapturedPage: Identifiable {
    let id = UUID()
    let data: Data
    let thumbnail: CGImage
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
#endif
