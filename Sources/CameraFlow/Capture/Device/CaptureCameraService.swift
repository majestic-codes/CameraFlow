//
//  CaptureCameraService.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import os

/// The device camera through AVFoundation.
@MainActor
final class CaptureCameraService: CameraService {
    private let core: CaptureSessionCore
    private(set) var photoCapabilities: PhotoCaptureCapabilities?
    private var eventDelivery: Task<Void, Never>?
    /// Whether the device has a pair of a back and a front camera that a multi-camera session runs.
    let isDualCameraSupported = CaptureDualFormats.devicePair() != nil
    /// The previews made so far, the newest last: the newest of each place shows the picture.
    private var viewfinderPreviews: [WeakPreview] = []
    private var circlePreviews: [WeakPreview] = []
    /// The layers of the two cameras of the pair, nil on a device that cannot run two cameras.
    private let dualLayers: DualPreviewLayers?
    /// The camera in the viewfinder of the pair, nil while one camera runs alone.
    private var dualMainPosition: CameraPosition?

    private struct WeakPreview {
        weak var preview: CaptureVideoPreview?
    }

    private static let logger = Logger.camera("CaptureCameraService")

    /// - Parameters:
    ///   - features: The costly photo features the flow can use. The session turns on no other.
    ///   - controlsSetup: What the Camera Control offers.
    init(features: PhotoCaptureFeatures, controlsSetup: CaptureControlsSetup) {
        let core = CaptureSessionCore(features: features, controlsSetup: controlsSetup)
        self.core = core
        dualLayers = DualPreviewLayers(core: core)
    }

    deinit {
        eventDelivery?.cancel()
    }

    var cameraPositions: [CameraPosition] {
        [CameraPosition.back, .front].filter { CaptureDeviceInspector.camera(at: $0) != nil }
    }

    var isAuthorizationDetermined: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) != .notDetermined
    }

    var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// Asks for camera access where it has no answer yet. An answer this code does not know is logged and taken for a
    /// denial.
    func requestAuthorization() async -> CameraAuthorization {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        @unknown default:
            Self.logger.error("Unknown camera authorization \(status.rawValue, privacy: .public) taken for a denial")
            return .denied
        }
    }

    func start(position: CameraPosition) async throws -> CameraCapabilities {
        let started = try await core.start(position: position)
        photoCapabilities = started.photo
        dualMainPosition = nil
        arrangePreviews()
        return started.camera
    }

    func startDualCamera(main: CameraPosition) async throws -> CameraCapabilities {
        let started = try await core.startDualCamera(main: main)
        photoCapabilities = started.photo
        dualMainPosition = main
        arrangePreviews()
        return started.camera
    }

    /// Puts the picture of the session that now runs on the previews: one camera in every viewfinder, or the pair
    /// with its main camera in the newest viewfinder and the other in the newest circle.
    private func arrangePreviews() {
        viewfinderPreviews.removeAll { $0.preview == nil }
        circlePreviews.removeAll { $0.preview == nil }
        guard let dualLayers, let dualMainPosition else {
            viewfinderPreviews.forEach { $0.preview?.showSingleCamera() }
            return
        }
        let mainLayer = dualLayers.layer(showing: dualMainPosition)
        viewfinderPreviews.last?.preview?.showDualCamera(in: mainLayer)
        let circleLayer = dualLayers.layer(showing: dualMainPosition.flipped)
        circlePreviews.last?.preview?.showDualCamera(in: circleLayer)
    }

    func stop() {
        core.stop()
    }

    /// The events cross from the session queue through one stream, so the handler gets them in the order the
    /// session reported them.
    func setEventHandler(_ handler: @escaping @MainActor (CameraSessionEvent) -> Void) {
        eventDelivery?.cancel()
        let (events, continuation) = AsyncStream<CameraSessionEvent>.makeStream()
        core.setEventHandler { event in
            continuation.yield(event)
        }
        eventDelivery = Task { @MainActor in
            for await event in events {
                handler(event)
            }
        }
    }

    func setZoom(_ factor: CGFloat) {
        core.setZoom(factor, rampRate: nil)
    }

    func rampZoom(to factor: CGFloat, rate: Float) {
        core.setZoom(factor, rampRate: rate)
    }

    func focus(atDevicePoint point: CGPoint) {
        core.focus(at: point)
    }

    func resetFocus() {
        core.resetFocus()
    }

    /// Asks the session queue for the lock before it suspends, so that a focus or a reset asked for next comes after
    /// it.
    func lockFocusAndExposure(atDevicePoint point: CGPoint) async -> Bool {
        await withCheckedContinuation { continuation in
            core.lockFocusAndExposure(at: point) { isLocked in
                continuation.resume(returning: isLocked)
            }
        }
    }

    func unlockFocusAndExposure() {
        core.unlockFocusAndExposure()
    }

    func setExposureBias(_ bias: Double) {
        core.setExposureBias(Float(bias))
    }

    func monitorFlashScene(for flashMode: CameraFlowFlashMode, format: CameraFlowPhotoFormat) {
        core.monitorFlashScene(for: flashMode, format: format)
    }

    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> CapturedPhoto {
        try await core.capturePhoto(request)
    }

    func selectCaptureControlLens(at index: Int) {
        core.selectCaptureControlLens(at: index)
    }

    func makePreview() -> any CameraPreview {
        let preview = CaptureVideoPreview(core: core)
        viewfinderPreviews.append(WeakPreview(preview: preview))
        arrangePreviews()
        return preview
    }

    func makeCirclePreview() -> any CameraPreview {
        let preview = CaptureVideoPreview()
        circlePreviews.append(WeakPreview(preview: preview))
        arrangePreviews()
        return preview
    }
}
#endif
