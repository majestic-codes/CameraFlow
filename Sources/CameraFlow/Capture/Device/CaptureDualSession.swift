//
//  CaptureDualSession.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import os

/// The back and the front camera together in the multi-camera session of `CaptureSessionCore`: one in the
/// viewfinder, the other in the circle, and the two can swap. It is made, run and torn down on the queue of the core,
/// like everything the core owns. The session outlives it, since the preview layers stay attached to it for their
/// whole life.
///
/// Every connection is made by hand: each camera feeds its own photo output and its own preview layer, and those
/// connections stay for the life of the pair. The cameras swap places on screen by the layers changing places, never
/// by a layer changing its camera. A preview turns with its own camera's rotation coordinator, since the cameras are
/// mounted in different turns, and shows the front camera mirrored. No photo is mirrored: the front camera's shows the
/// scene as the camera saw it, in the viewfinder and in the circle alike.
final class CaptureDualSession {
    let session: AVCaptureMultiCamSession
    /// The camera in the viewfinder; the other one is in the circle. The cameras swap places without a connection
    /// added or removed.
    var mainPosition: CameraPosition
    private let back: Camera
    private let front: Camera
    private let queue: DispatchQueue
    /// The costly photo features the flow can use: no other is turned on.
    private let features: PhotoCaptureFeatures
    private var previewLevels: [ObjectIdentifier: PreviewLevel] = [:]
    private var pressureObservations: [NSKeyValueObservation] = []

    /// One camera of the pair: its device, its port, its photo output and the coordinator its captures turn with.
    struct Camera {
        let position: CameraPosition
        let device: AVCaptureDevice
        let input: AVCaptureDeviceInput
        let port: AVCaptureInput.Port
        let photoOutput = AVCapturePhotoOutput()
        let captureRotation: AVCaptureDevice.RotationCoordinator

        /// Turns the photos taken now level with the horizon, as this camera is held.
        func levelCaptures() {
            if let connection = photoOutput.connection(with: .video) {
                CaptureRotation.rotate(connection, to: captureRotation.videoRotationAngleForHorizonLevelCapture)
            }
        }
    }

    private static let logger = Logger.camera("CaptureDualSession")
    /// The angle that shows the back camera in the portrait of the interface. The quarter turns of a capture are
    /// counted from it.
    static let backPortraitAngle: CGFloat = 90
    /// The frame rate both cameras are held to, which keeps the hardware cost of the pair down.
    private static let frameDuration = CMTime(value: 1, timescale: 30)

    /// Configures the pair in formats that fit the hardware cost and the system pressure of running both, and reports
    /// the system pressure on each camera now and whenever it changes.
    init(
        session: AVCaptureMultiCamSession,
        pair: CaptureDualFormats.DevicePair,
        mainPosition: CameraPosition,
        features: PhotoCaptureFeatures,
        queue: DispatchQueue,
        onPressure: @escaping @Sendable (CameraPosition, CaptureSystemPressure) -> Void
    ) throws {
        self.session = session
        back = try Self.camera(pair.back, at: .back)
        front = try Self.camera(pair.front, at: .front)
        self.mainPosition = mainPosition
        self.features = features
        self.queue = queue
        try connectPhotoOutputs()
        try chooseFormats()
        configurePhotoOutputs()
        pressureObservations = [back, front].map { camera in
            let position = camera.position
            return camera.device.observe(\.systemPressureState, options: [.initial, .new]) { device, _ in
                onPressure(position, CaptureDeviceInspector.pressure(of: device.systemPressureState))
            }
        }
    }

    deinit {
        pressureObservations.forEach { $0.invalidate() }
    }

    var main: Camera {
        camera(at: mainPosition)
    }

    var circle: Camera {
        camera(at: mainPosition.flipped)
    }

    func camera(at position: CameraPosition) -> Camera {
        position == .back ? back : front
    }

    func start() {
        if !session.isRunning {
            session.startRunning()
        }
    }

    func stop() {
        session.stopRunning()
    }

    /// Stops the pair and takes both cameras, their outputs and every connection out of the session, so that a camera
    /// can run alone in the other session. The preview layers stay attached to the session, without a connection.
    func tearDown() {
        session.stopRunning()
        session.beginConfiguration()
        session.connections.forEach(session.removeConnection)
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        session.commitConfiguration()
    }

    /// The quarter turns from the viewfinder to a photo taken now, from the way the back camera is held.
    var viewfinderQuarterTurns: Int {
        let angle = back.captureRotation.videoRotationAngleForHorizonLevelCapture
        return DualCameraPlacement.quarterTurns(captureAngle: angle, portraitAngle: Self.backPortraitAngle)
    }

    /// Shows the camera at `position` in a layer attached to the session, for the life of the pair. A layer that
    /// already shows it is left as it is, so a swap and a restart never touch a connection that works.
    func show(cameraAt position: CameraPosition, in layer: AVCaptureVideoPreviewLayer) {
        let camera = camera(at: position)
        // A layer made with no connection shows nothing until one is added by hand. The session keeps that
        // connection while the layer changes its place on screen, so it is added once for each pair.
        let existing = layer.connection
        if let existing, existing.inputPorts.contains(camera.port) {
            return
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // A layer takes one connection only. One that is left is to a port of an earlier pair, whose inputs are
        // gone, and it goes before the new one comes.
        if let existing {
            session.removeConnection(existing)
        }
        // The port is the camera's own video port: in a multi-camera session a connection names its camera.
        let connection = AVCaptureConnection(inputPort: camera.port, videoPreviewLayer: layer)
        guard session.canAddConnection(connection) else {
            let cameraName = String(describing: position)
            let hadConnection = existing != nil
            Self.logger.error(
                """
                The dual camera refused the preview connection of the \(cameraName, privacy: .public) camera, \
                the layer had a connection before: \(hadConnection, privacy: .public)
                """
            )
            return
        }
        session.addConnection(connection)
        // The session mirrors no preview by itself here, and the front camera is shown as a selfie.
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = camera.position.isMirroredOnScreen
        } else if camera.position.isMirroredOnScreen {
            Self.logger.error("The preview connection of the front camera cannot be mirrored")
        }
        let level = PreviewLevel(connection, of: layer, device: camera.device, queue: queue)
        previewLevels[ObjectIdentifier(layer)] = level
    }

    private func connectPhotoOutputs() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        for camera in [back, front] {
            guard session.canAddInput(camera.input) else {
                throw CameraServiceError.dualCameraUnavailable("The dual camera refused a camera input")
            }
            session.addInputWithNoConnections(camera.input)
            guard session.canAddOutput(camera.photoOutput) else {
                throw CameraServiceError.dualCameraUnavailable("The dual camera refused a photo output")
            }
            session.addOutputWithNoConnections(camera.photoOutput)
            let connection = AVCaptureConnection(inputPorts: [camera.port], output: camera.photoOutput)
            guard session.canAddConnection(connection) else {
                throw CameraServiceError.dualCameraUnavailable("The dual camera refused a photo connection")
            }
            session.addConnection(connection)
        }
    }

    /// Tries the back camera's formats from the largest photo down, each with the front formats in their order,
    /// and keeps the first pair the hardware can run sustainably.
    private func chooseFormats() throws {
        let frontFormats = CaptureDualFormats.frontFormats(of: front.device)
        for backFormat in CaptureDualFormats.backFormats(of: back.device) {
            for frontFormat in frontFormats {
                try apply(backFormat, frontFormat)
                let hardwareCost = session.hardwareCost
                let pressureCost = session.systemPressureCost
                if hardwareCost <= 1, pressureCost <= 1 {
                    let description = "back \(backFormat), front \(frontFormat), hardware cost \(hardwareCost), "
                        + "system pressure cost \(pressureCost)"
                    Self.logger.info("Dual camera formats chosen: \(description, privacy: .public)")
                    return
                }
            }
        }
        throw CameraServiceError.dualCameraUnavailable("No pair of formats fits the hardware of the dual camera")
    }

    private func apply(_ backFormat: AVCaptureDevice.Format, _ frontFormat: AVCaptureDevice.Format) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        for (camera, format) in [(back, backFormat), (front, frontFormat)] {
            do {
                try camera.device.lockForConfiguration()
            } catch {
                throw CameraServiceError.dualCameraUnavailable(error.localizedDescription)
            }
            camera.device.activeFormat = format
            camera.device.unlockForConfiguration()
            camera.input.videoMinFrameDurationOverride = Self.frameDuration
        }
    }

    /// Turns on what each camera's format offers for photos and the flow can use, as the single camera does.
    private func configurePhotoOutputs() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        for camera in [back, front] {
            CapturePhotoOutputSetup.configure(camera.photoOutput, for: camera.device, features: features)
        }
    }

    private static func camera(_ device: AVCaptureDevice, at position: CameraPosition) throws -> Camera {
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraServiceError.dualCameraUnavailable(error.localizedDescription)
        }
        guard let port = input.ports.first(where: { $0.mediaType == .video }) else {
            throw CameraServiceError.dualCameraUnavailable("A camera of the pair has no video port")
        }
        return Camera(
            position: position,
            device: device,
            input: input,
            port: port,
            captureRotation: AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        )
    }
}

/// A layer of the single camera, held weakly: the camera service owns it. Once handed to `CaptureSessionCore`, its
/// connection is set on the core's queue only, which is what makes the unchecked sendability hold.
struct SinglePreviewLayerReference: @unchecked Sendable {
    weak var layer: AVCaptureVideoPreviewLayer?
}

/// A preview layer attached to the multi-camera session and the camera of the pair it shows, held weakly: the
/// camera service owns it. Once handed to `CaptureSessionCore`, its connection is set on the core's queue only, which
/// is what makes the unchecked sendability hold.
struct DualPreviewLayerReference: @unchecked Sendable {
    weak var layer: AVCaptureVideoPreviewLayer?
    let position: CameraPosition
}
#endif
