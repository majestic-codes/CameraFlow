//
//  CameraService.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

enum CameraPosition: Sendable, Equatable {
    case back
    case front

    var flipped: Self {
        switch self {
        case .back: .front
        case .front: .back
        }
    }

    /// Whether the screen shows this camera mirrored, as a selfie: the front camera in the viewfinder and in the
    /// circle alike. A photo never is: it shows the scene as the camera saw it, as the stock camera saves it.
    var isMirroredOnScreen: Bool {
        self == .front
    }
}

enum CameraAuthorization: Sendable, Equatable {
    case authorized
    /// The user said no, now or earlier.
    case denied
    /// A device policy, such as Screen Time or a profile, blocks the camera and the user cannot change it.
    case restricted
}

/// One lens button. The factor is the one shown to the user, so the main camera is always 1.
struct CameraLens: Sendable, Equatable {
    let factor: CGFloat
    /// 35 mm equivalent focal length, known for physical lenses only.
    let focalLength: Int?
}

/// What the running camera can do, in displayed zoom factors.
struct CameraCapabilities: Sendable, Equatable {
    let position: CameraPosition
    let lenses: [CameraLens]
    let zoomRange: ClosedRange<CGFloat>
    /// Extra factors the dial marks with a dot, such as the 28 mm and 35 mm framings of the main camera.
    let markedFactors: [CGFloat]
}

enum CameraServiceError: Error, Equatable {
    case noCamera
    case cannotUseCamera(String)
    case notRunning
    case captureFailed(String)
    case noImageData
    /// The session is interrupted, for example by a call or another app using the camera.
    case interrupted(CameraInterruption)
    /// The request asks for something the running camera does not offer.
    case unsupported(PhotoCaptureOption)
    case cannotCrop(String)
    /// The files of a capture cannot be written to the session's directory.
    case cannotStore(String)
    /// The device has too little room left for the files of a photo.
    case notEnoughStorage
    /// The back and the front camera cannot run together on this device now.
    case dualCameraUnavailable(String)
    /// The screen already holds as many photos as it takes.
    case captureLimitReached(Int)
}

/// The device camera as the screen sees it. Zoom factors are the displayed ones.
@MainActor
protocol CameraService: AnyObject {
    /// The sides that have a camera, the back first. Empty on a device without one, which is never asked for access.
    var cameraPositions: [CameraPosition] { get }
    /// Whether camera access already has an answer, the user's or a device policy's, so asking shows no request.
    var isAuthorizationDetermined: Bool { get }
    /// Whether camera access is granted already, so asking returns at once with a yes.
    var isAuthorized: Bool { get }
    func requestAuthorization() async -> CameraAuthorization
    /// Configures the camera at the position and starts it. Calling it again switches the camera, and a dual camera
    /// goes back to that one camera alone and releases the other.
    func start(position: CameraPosition) async throws -> CameraCapabilities
    /// Whether the device can run the back and the front camera at the same time. A dual start may still fail
    /// when no pair of formats fits the hardware.
    var isDualCameraSupported: Bool { get }
    /// Runs the back and the front camera together, the one at `main` in the viewfinder and the other in the
    /// circle, and returns what the main one can do. Calling it again with the other position swaps the two. From
    /// then on `photoCapabilities` describes the main camera of the pair, and a capture brings a frame of the other.
    func startDualCamera(main: CameraPosition) async throws -> CameraCapabilities
    func stop()
    func setZoom(_ factor: CGFloat)
    /// Zooms smoothly. The rate is in doublings per second.
    func rampZoom(to factor: CGFloat, rate: Float)
    /// Focuses and exposes once at a point in the camera's coordinates, as a preview converts it, and stays there.
    /// The camera reports `CameraSessionEvent.subjectAreaChanged` when its picture changes a lot meanwhile.
    func focus(atDevicePoint point: CGPoint)
    /// Focuses and exposes by itself again, at the centre of the picture, as the camera does before a tap.
    func resetFocus()
    /// Focuses and exposes once at a point, as `focus(atDevicePoint:)` does but without watching the picture, and
    /// locks both once the camera has settled. Returns whether the lock holds: false when a focus, a reset, an
    /// unlock, a new lock, a start or a stop came first. The exposure bias still applies to a locked exposure.
    func lockFocusAndExposure(atDevicePoint point: CGPoint) async -> Bool
    /// Gives up a lock, whether it holds or still settles: the camera watches its picture again, as after a focus at
    /// the lock's point, and reports `CameraSessionEvent.subjectAreaChanged` when it changes a lot.
    func unlockFocusAndExposure()
    /// What the running camera can do for photos, nil until `start(position:)` has returned.
    var photoCapabilities: PhotoCaptureCapabilities? { get }
    /// Receives interruptions, Camera Control changes and runtime errors, on the main actor.
    func setEventHandler(_ handler: @escaping @MainActor (CameraSessionEvent) -> Void)
    /// Exposure target bias in stops, inside `photoCapabilities.exposureBiasRange`.
    func setExposureBias(_ bias: Double)
    /// Monitors the scene of the camera in the viewfinder, and of every camera that comes into the viewfinder later,
    /// for the flash in this mode, as far as the camera offers it, as the next photo in `format` would be taken: with
    /// the quality prioritization of that capture, which moves the light level the flash fires at. It reports
    /// `CameraSessionEvent.flashSceneChanged` whenever its scene starts or stops needing the flash.
    func monitorFlashScene(for flashMode: CameraFlowFlashMode, format: CameraFlowPhotoFormat)
    /// Takes one photo. The request has been checked against `photoCapabilities` by the caller. A capture never
    /// outlives its session: when the camera is stopped, fails or is started again before the photo is delivered,
    /// the capture throws `CameraServiceError.notRunning`.
    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> CapturedPhoto
    /// Shows the lens at an index of `CameraCapabilities.lenses` as picked in the Camera Control's lens picker.
    func selectCaptureControlLens(at index: Int)
    /// A preview of what the camera in the viewfinder sees, the front one mirrored like a selfie.
    func makePreview() -> any CameraPreview
    /// A preview of the camera in the circle of a dual camera, the front one mirrored like a selfie. It is empty
    /// while no dual camera runs.
    func makeCirclePreview() -> any CameraPreview
}

extension CameraService {
    /// Whether the device has a camera at all. One without is never asked for access.
    var hasCamera: Bool {
        !cameraPositions.isEmpty
    }
}
