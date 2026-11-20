import SwiftUI
import Combine
import AVFoundation
import Roboflow

nonisolated private struct CameraDetection: Identifiable {
    let id = UUID()
    let box: CGRect
    let label: String
}

nonisolated private final class LiveCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    @Published var detections: [CameraDetection] = []
    @Published var message = "Starting camera…"
    @Published var ready = false
    @Published var imageSize = CGSize(width: 3, height: 4)
    var onPhoto: ((UIImage) -> Void)?
    private let queue = DispatchQueue(label: "biteai.camera")
    private let videoQueue = DispatchQueue(label: "biteai.camera.inference")
    private let photoOutput = AVCapturePhotoOutput()
    private var model: RFModel?
    private var processing = false
    private var active = false
    private var lastFrame = Date.distantPast

    func start(apiKey: String, modelID: String, version: Int?) {
        active = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                DispatchQueue.main.async {
                    guard let self, self.active else { return }
                    if allowed { self.configureCamera() } else { self.show("Camera access is disabled. Enable it in Settings.") }
                }
            }
        default: show("Camera access is disabled. Enable it in Settings.")
        }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !modelID.isEmpty, let version, version > 0 else {
            show("Add your Roboflow model details in Model settings to see live detections.")
            return
        }
        let client = RoboflowMobile(apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        client.load(model: modelID, modelVersion: version) { [weak self] model, error, _, _ in
            guard let self else { return }
            guard let model, error == nil else {
                self.show("Model could not load: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            model.configure(threshold: 0.5, overlap: 0.4, maxObjects: 20)
            self.videoQueue.async {
                self.model = model
                DispatchQueue.main.async { if self.active { self.message = "Point the camera at your food" } }
            }
        }
    }

    private func show(_ text: String) { DispatchQueue.main.async { [weak self] in self?.message = text } }

    private func configureCamera() {
        queue.async { [weak self] in
            guard let self else { return }
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.show("Camera is unavailable on this device.")
                return
            }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            guard self.session.canAddInput(input), self.session.canAddOutput(self.photoOutput) else {
                self.session.commitConfiguration()
                self.show("Could not start the camera.")
                return
            }
            self.session.addInput(input)
            self.session.addOutput(self.photoOutput)
            let video = AVCaptureVideoDataOutput()
            video.alwaysDiscardsLateVideoFrames = true
            video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            guard self.session.canAddOutput(video) else {
                self.session.commitConfiguration()
                self.show("Live detection is unavailable.")
                return
            }
            self.session.addOutput(video)
            video.setSampleBufferDelegate(self, queue: self.videoQueue)
            if let connection = video.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async { self.ready = true }
        }
    }

    func stop() {
        active = false
        queue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    func capture() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            if let connection = self.photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let model, !processing, Date().timeIntervalSince(lastFrame) >= 0.25,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        processing = true
        lastFrame = Date()
        let width = CGFloat(CVPixelBufferGetWidth(buffer)), height = CGFloat(CVPixelBufferGetHeight(buffer))
        model.detect(pixelBuffer: buffer) { [weak self] predictions, error in
            guard let self else { return }
            let boxes = (predictions ?? []).compactMap { prediction -> CameraDetection? in
                guard let p = prediction as? RFObjectDetectionPrediction, width > 0, height > 0 else { return nil }
                return CameraDetection(box: CGRect(x: p.box.minX / width, y: p.box.minY / height, width: p.box.width / width, height: p.box.height / height), label: "\(p.className) \(Int(p.confidence * 100))%")
            }
            self.videoQueue.async {
                self.processing = false
                DispatchQueue.main.async {
                    guard self.active else { return }
                    self.imageSize = CGSize(width: width, height: height)
                    self.detections = boxes
                    if let error { self.message = "Detection failed: \(error.localizedDescription)" }
                }
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data), error == nil else {
            show("Could not capture the photo. Please try again.")
            return
        }
        DispatchQueue.main.async { [weak self] in self?.onPhoto?(image) }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.preview.session = session
        view.preview.videoGravity = .resizeAspectFill
        if let connection = view.preview.connection, connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) {}
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

struct LiveCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    let apiKey: String
    let modelID: String
    let version: Int?
    @StateObject private var camera = LiveCamera()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                CameraPreview(session: camera.session).ignoresSafeArea()
                // The preview and video output are both portrait, with aspect-fill cropping.
                GeometryReader { frame in
                    let source = camera.imageSize
                    let scale = max(frame.size.width / source.width, frame.size.height / source.height)
                    let size = CGSize(width: source.width * scale, height: source.height * scale)
                    let origin = CGPoint(x: (frame.size.width - size.width) / 2, y: (frame.size.height - size.height) / 2)
                    ForEach(camera.detections) { detection in
                        let box = CGRect(x: origin.x + detection.box.minX * size.width, y: origin.y + detection.box.minY * size.height, width: detection.box.width * size.width, height: detection.box.height * size.height)
                        ZStack(alignment: .topLeading) {
                            Rectangle().stroke(.green, lineWidth: 3)
                            Text(detection.label).font(.caption.bold()).foregroundStyle(.white).padding(4).background(.green)
                        }.frame(width: max(box.width, 0), height: max(box.height, 0)).position(x: box.midX, y: box.midY)
                    }
                }.allowsHitTesting(false).ignoresSafeArea()
                VStack {
                    HStack {
                        Button("Cancel") { dismiss() }.foregroundStyle(.white).padding(12).background(.black.opacity(0.6), in: Capsule())
                        Spacer()
                    }
                    Spacer()
                    Text(camera.message).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.white).padding(10).background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                    Button { camera.capture() } label: {
                        Circle().fill(.white).frame(width: 68, height: 68).overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 3).padding(5))
                    }.disabled(!camera.ready).accessibilityLabel("Take photo").padding(.top, 12)
                }.padding(20)
            }
        }
        .onAppear {
            camera.onPhoto = { photo in image = photo; dismiss() }
            camera.start(apiKey: apiKey, modelID: modelID, version: version)
        }
        .onDisappear { camera.stop() }
    }
}
