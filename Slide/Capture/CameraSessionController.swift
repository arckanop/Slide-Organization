#if os(iOS)
@preconcurrency import AVFoundation
import Observation

/// Owns the `AVCaptureSession` for the rapid-multi-shot normal-camera mode.
/// `startRunning()`/`stopRunning()` are genuinely blocking calls per Apple's
/// docs, so they're bounced onto a private serial queue; everything else
/// (configuration, delegate bookkeeping) stays on the main actor like the
/// rest of the app.
@Observable
final class CameraSessionController: NSObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "slide.camera.session")
    private var isConfigured = false
    private var activeDelegates: [PhotoCaptureDelegate] = []

    var permissionDenied = false
    var isRunning = false

    func start() {
        Task {
            guard await requestAccess() else {
                permissionDenied = true
                return
            }
            configureIfNeeded()
            await runSession(start: true)
            isRunning = true
        }
    }

    func stop() {
        Task {
            await runSession(start: false)
            isRunning = false
            activeDelegates.removeAll()
        }
    }

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        let settings = AVCapturePhotoSettings()
        let delegate = PhotoCaptureDelegate { data in
            Task { @MainActor in completion(data) }
        }
        activeDelegates.append(delegate)
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
        isConfigured = true
    }

    private func runSession(start: Bool) async {
        let session = self.session
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if start {
                    if !session.isRunning { session.startRunning() }
                } else if session.isRunning {
                    session.stopRunning()
                }
                continuation.resume()
            }
        }
    }
}

private nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onComplete: (Data?) -> Void

    init(onComplete: @escaping (Data?) -> Void) {
        self.onComplete = onComplete
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        onComplete(data)
    }
}
#endif
