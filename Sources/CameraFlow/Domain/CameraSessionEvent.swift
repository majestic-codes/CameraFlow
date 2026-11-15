//
//  CameraSessionEvent.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Why the session stopped delivering frames for a while.
enum CameraInterruption: Sendable, Equatable {
    case cameraInUseByAnotherClient
    case audioInUseByAnotherClient
    case cameraUnavailableInBackground
    case cameraUnavailableBesideOtherApps
    case cameraUnavailableUnderPressure
    /// A sensitive content analyzer paused the camera.
    case sensitiveContentMitigationActivated
    /// A reason this code does not know yet, with the raw value AVFoundation reported.
    case other(Int)
}

/// An error that stopped the running session on its own, outside any call.
struct CameraRuntimeError: Sendable, Equatable {
    /// The error in the system's words.
    let message: String
    /// Whether starting the camera again is known to recover from it, as after a reset of the media services.
    let isRecoverable: Bool
}

/// Something the session reports on its own, outside any call.
enum CameraSessionEvent: Sendable, Equatable {
    case interrupted(CameraInterruption)
    case interruptionEnded
    /// The session stopped with an error and has to be started again.
    case runtimeError(CameraRuntimeError)
    /// The Camera Control changed a value or its overlay.
    case captureControl(CaptureControlEvent)
    /// The system pressure on a dual camera reached the level where it has to give up one camera.
    case dualCameraPressureCritical
    /// The picture of the camera in the viewfinder changed a lot since it focused at a point: another subject, other
    /// light or another framing.
    case subjectAreaChanged
    /// How ready the camera is to take another photo changed.
    case captureReadinessChanged(CaptureReadiness)
    /// Whether the scene of the camera in the viewfinder is dark enough for the flash in the mode it monitors
    /// (`CameraService.monitorFlashScene(for:format:)`): reported when a camera comes into the viewfinder and
    /// whenever it changes.
    case flashSceneChanged(Bool)
    /// Whether the flash of the camera in the viewfinder can fire: reported when a camera comes into the viewfinder
    /// and whenever it changes.
    case flashAvailabilityChanged(FlashAvailability)
}
