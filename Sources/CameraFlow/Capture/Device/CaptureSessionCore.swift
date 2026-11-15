//
//  CaptureSessionCore.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import CoreLocation
import os

/// Owns the capture sessions: the session of one camera and, where the device can run two cameras, the multi-camera
/// session of the dual camera. Everything mutable is read and written on its queue only, which is what makes the
/// unchecked sendability hold. A member that its extensions or other files call on the queue asserts the queue, and
/// every other member reaches the queue itself.
///
/// A preview layer is attached to one of the two sessions when it is made and stays with it: moving a layer to the
/// other session races with the configuration the first one is still making live, which AVFoundation asserts on.
/// The screen shows the layer of the session that runs. A layer of the multi-camera session also stays with one
/// camera of the pair, and the screen puts it where that camera shows.
final class CaptureSessionCore: @unchecked Sendable {
    typealias EventHandler = @Sendable (CameraSessionEvent) -> Void

    let session = AVCaptureSession()
    /// The session of the dual camera, nil on a device that cannot run two cameras.
    let multiCamSession: AVCaptureMultiCamSession? = AVCaptureMultiCamSession.isMultiCamSupported
        ? AVCaptureMultiCamSession()
        : nil
    /// The costly photo features the flow can use: no other is turned on.
    private let features: PhotoCaptureFeatures
    /// What the Camera Control offers.
    private let controlsSetup: CaptureControlsSetup
    let photoOutput = AVCapturePhotoOutput()
    let queue = DispatchQueue(label: "CameraFlow.capture-session")
    private(set) var input: AVCaptureDeviceInput?
    /// The back and the front camera together, nil while one camera runs alone.
    private(set) var dual: CaptureDualSession?
    private var dualObserver: CaptureSessionObserver?
    private var previewLayers: [DualPreviewLayerReference] = []
    /// The display multiplier of the camera in the viewfinder.
    private var runningDisplayMultiplier: CGFloat = 1
    private var processors: [Int64: CapturePhotoProcessor] = [:]
    let capturesInFlight = CapturesInFlight()
    /// The lock of the focus and the exposure that waits for the camera in the viewfinder to settle.
    let focusLockWait = CaptureFocusLockWait()
    private(set) var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    /// The layers of the viewfinder that show the single camera, kept level with their interface.
    private lazy var singlePreviews = SinglePreviewLevels(queue: queue)
    private var sessionObserver: CaptureSessionObserver?
    /// Watches the camera in the viewfinder for a change of its picture, nil before a camera ran.
    private var subjectAreaObserver: CaptureSubjectAreaObserver?
    /// Follows the system pressure on the single camera, nil while the pair runs.
    private var pressureObservation: NSKeyValueObservation?
    /// The scene and the flash of the camera in the viewfinder, followed while a camera runs.
    private(set) lazy var flashWatch = CaptureFlashWatch(queue: queue)
    private(set) var eventHandler: EventHandler?
    /// The readiness of the outputs that take photos now, which reaches the event handler.
    private lazy var captureReadiness = CaptureReadinessTracker(queue: queue) { [weak self] readiness in
        self?.eventHandler?(.captureReadinessChanged(readiness))
    }
    /// The Camera Control's controls of the single camera and of the pair, nil where a session has none.
    private lazy var captureControls = makeCaptureControls(for: session)
    private lazy var dualCaptureControls = multiCamSession.flatMap { makeCaptureControls(for: $0) }

    static let logger = Logger.camera("CaptureSessionCore")

    init(features: PhotoCaptureFeatures, controlsSetup: CaptureControlsSetup) {
        self.features = features
        self.controlsSetup = controlsSetup
    }

    func setEventHandler(_ handler: @escaping EventHandler) {
        queue.async {
            self.eventHandler = handler
            if self.sessionObserver == nil {
                self.sessionObserver = self.makeObserver(of: self.session)
            }
            self.captureReadiness.reportAgain()
        }
    }

    typealias Started = (camera: CameraCapabilities, photo: PhotoCaptureCapabilities)

    func start(position: CameraPosition) async throws -> Started {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.capturesInFlight.failAll()
                self.focusLockWait.end(isLocked: false)
                self.endDualCamera()
                let result = Result { try self.configure(position: position) }
                if case .success = result {
                    self.levelSinglePreviews()
                    self.run()
                }
                continuation.resume(with: result)
            }
        }
    }

    /// Runs the back and the front camera together with the one at `main` in the viewfinder, or swaps a pair that
    /// runs. The camera that ran alone is let go first; when the pair cannot run, nothing runs and the error says
    /// why.
    func startDualCamera(main: CameraPosition) async throws -> Started {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.capturesInFlight.failAll()
                self.focusLockWait.end(isLocked: false)
                continuation.resume(with: Result { try self.configureDualCamera(main: main) })
            }
        }
    }

    func stop() {
        queue.async {
            self.session.stopRunning()
            self.dual?.stop()
            self.capturesInFlight.failAll()
            self.focusLockWait.end(isLocked: false)
            self.flashWatch.stop()
        }
    }

    /// Keeps a layer of the single camera level with the interface it is shown in, for as long as the layer lives.
    func addSinglePreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        let reference = SinglePreviewLayerReference(layer: layer)
        queue.async {
            self.singlePreviews.add(reference)
            self.levelSinglePreviews()
        }
    }

    private func levelSinglePreviews() {
        singlePreviews.level(with: input?.device)
    }

    /// Shows one camera of the pair in a layer attached to the multi-camera session, whenever the pair runs and
    /// for as long as the layer lives.
    func addDualPreviewLayer(_ layer: AVCaptureVideoPreviewLayer, showing position: CameraPosition) {
        let reference = DualPreviewLayerReference(layer: layer, position: position)
        queue.async {
            guard let layer = reference.layer else { return }
            self.previewLayers.removeAll { $0.layer == nil }
            self.previewLayers.append(reference)
            self.dual?.show(cameraAt: position, in: layer)
        }
    }

    /// The camera that zooms, focuses and exposes: the one in the viewfinder. Read on the queue only.
    var controlledDevice: AVCaptureDevice? {
        dispatchPrecondition(condition: .onQueue(queue))
        return dual?.main.device ?? input?.device
    }

    /// Multiplies a zoom factor of the camera in the viewfinder into the displayed one. Read on the queue only.
    var displayMultiplier: CGFloat {
        dispatchPrecondition(condition: .onQueue(queue))
        return runningDisplayMultiplier
    }

    private func makeCaptureControls(for session: AVCaptureSession) -> (any CaptureControlsBinding)? {
        CaptureSessionControls.make(session: session, queue: queue, setup: controlsSetup) { [weak self] event in
            self?.eventHandler?(.captureControl(event))
        }
    }

    /// Moves the lens picker of the session that runs.
    func selectCaptureControlLens(at index: Int) {
        queue.async {
            let controls = self.dual == nil ? self.captureControls : self.dualCaptureControls
            controls?.selectLens(at: index)
        }
    }

    /// Fires one capture of an output and keeps its delegate until the capture finishes.
    func capture(
        _ built: CapturePhotoSettingsBuilder.Built,
        location: CLLocation?,
        with output: AVCapturePhotoOutput,
        completion: @escaping @Sendable (Result<CapturedPhoto, any Error>) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(queue))
        let identifier = built.settings.uniqueID
        let processor = CapturePhotoProcessor(
            encoding: built.encoding,
            location: location,
            requestedMovieURL: built.settings.livePhotoMovieFileURL
        ) { result in
            self.queue.async {
                self.processors[identifier] = nil
            }
            completion(result)
        }
        processors[identifier] = processor
        captureReadiness.track(built.settings, on: output)
        output.capturePhoto(with: built.settings, delegate: processor)
    }

    private func configure(position: CameraPosition) throws -> Started {
        guard let device = CaptureDeviceInspector.camera(at: position) else {
            throw CameraServiceError.noCamera
        }
        let newInput: AVCaptureDeviceInput
        do {
            newInput = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraServiceError.cannotUseCamera(error.localizedDescription)
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        if let input {
            session.removeInput(input)
        }
        guard session.canAddInput(newInput) else {
            if let input {
                session.addInput(input)
            }
            throw CameraServiceError.cannotUseCamera("The session refused the camera input")
        }
        session.addInput(newInput)
        input = newInput
        CaptureDeviceControl.resetFocus(on: device)
        subjectAreaObserver = makeSubjectAreaObserver(of: device)
        pressureObservation = makePressureObservation(of: device)
        if !session.outputs.contains(photoOutput) {
            guard session.canAddOutput(photoOutput) else {
                throw CameraServiceError.cannotUseCamera("The session refused the photo output")
            }
            session.addOutput(photoOutput)
        }
        CapturePhotoOutputSetup.configure(photoOutput, for: device, features: features)
        captureReadiness.follow([photoOutput])
        watchFlash(of: device, output: photoOutput)
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        let optics = CaptureDeviceInspector.optics(of: device)
        runningDisplayMultiplier = optics.displayMultiplier
        let camera = LensCatalog.capabilities(position: position, optics: optics)
        captureControls?.bind(to: device, lenses: camera.lenses, displayMultiplier: optics.displayMultiplier)
        let photo = CaptureDeviceInspector.photoCapabilities(of: device, output: photoOutput)
        return (camera, photo)
    }

    /// Puts the committed camera on its main lens and starts the session.
    private func run() {
        if let device = input?.device {
            CaptureDeviceControl.zoomToMainLens(device, displayMultiplier: displayMultiplier)
        }
        if !session.isRunning {
            session.startRunning()
        }
    }
}

extension CaptureSessionCore {

    /// Lets the single camera go, sets up the pair and starts it, or swaps a pair that runs or was stopped, with
    /// the camera of the viewfinder on its main lens.
    private func configureDualCamera(main: CameraPosition) throws -> Started {
        let dual = try self.dual ?? makeDualCamera(main: main)
        dual.mainPosition = main
        for camera in [dual.main, dual.circle] {
            CaptureDeviceControl.resetFocus(on: camera.device)
        }
        subjectAreaObserver = makeSubjectAreaObserver(of: dual.main.device)
        watchFlash(of: dual.main.device, output: dual.main.photoOutput)
        connectPreviews(of: dual)
        captureReadiness.follow([dual.main.photoOutput, dual.circle.photoOutput])
        let device = dual.main.device
        let optics = CaptureDeviceInspector.optics(of: device)
        runningDisplayMultiplier = optics.displayMultiplier
        dual.start()
        CaptureDeviceControl.zoomToMainLens(device, displayMultiplier: displayMultiplier)
        // The camera that goes into the circle leaves the zoom it had in the viewfinder.
        let circleDevice = dual.circle.device
        let circleMultiplier = CaptureDeviceInspector.optics(of: circleDevice).displayMultiplier
        CaptureDeviceControl.zoomToMainLens(circleDevice, displayMultiplier: circleMultiplier)
        let camera = LensCatalog.capabilities(position: main, optics: optics)
        dualCaptureControls?.bind(to: device, lenses: camera.lenses, displayMultiplier: optics.displayMultiplier)
        let photo = CaptureDeviceInspector.photoCapabilities(of: device, output: dual.main.photoOutput)
        return (camera, photo)
    }

    private func makeDualCamera(main: CameraPosition) throws -> CaptureDualSession {
        guard let pair = CaptureDualFormats.devicePair() else {
            throw CameraServiceError.dualCameraUnavailable("This device cannot run the back and the front camera")
        }
        session.stopRunning()
        if let input {
            session.beginConfiguration()
            session.removeInput(input)
            session.commitConfiguration()
            self.input = nil
            pressureObservation = nil
        }
        guard let multiCamSession else {
            throw CameraServiceError.dualCameraUnavailable("This device has no multi-camera session")
        }
        let dual = try CaptureDualSession(
            session: multiCamSession,
            pair: pair,
            mainPosition: main,
            features: features,
            queue: queue
        ) { [weak self] position, pressure in
            guard let self else { return }
            queue.async { self.dualCameraPressureChanged(to: pressure, at: position) }
        }
        self.dual = dual
        dualObserver = makeObserver(of: dual.session)
        return dual
    }

    /// Stops the pair and lets both its cameras go, so that one of them can run alone.
    private func endDualCamera() {
        guard let dual else { return }
        dual.tearDown()
        self.dual = nil
        dualObserver = nil
        captureReadiness.follow([])
    }

    /// Connects every layer of the multi-camera session that is not yet connected to its camera of the pair.
    private func connectPreviews(of dual: CaptureDualSession) {
        previewLayers.removeAll { $0.layer == nil }
        for reference in previewLayers {
            if let layer = reference.layer {
                dual.show(cameraAt: reference.position, in: layer)
            }
        }
    }
}
#endif
