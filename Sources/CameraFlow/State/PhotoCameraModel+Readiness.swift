//
//  PhotoCameraModel+Readiness.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

// MARK: - What the camera can do now, for the flow around it

extension PhotoCameraModel {
    /// Whether a photo is on its way: from a shutter tap until its photo is handed over or fails, the countdown
    /// included.
    var isCapturing: Bool {
        shutter.isCapturing
    }

    /// How many photos are on their way from the shutter, each from its tap until it is handed over or fails, the
    /// one of a running countdown included.
    var photosInFlight: Int {
        shutter.photosInFlight
    }

    /// How many photos the camera was asked to take that are still on their way, each from the moment its shot fires
    /// until it is handed over or fails: the photos leaving the flow now would lose. A countdown has none yet.
    var firedPhotosInFlight: Int {
        shutter.firedPhotosInFlight
    }

    /// Whether the self-timer counts down, which a tap of the shutter stops.
    var isCountingDown: Bool {
        shutter.isCountingDown
    }

    /// Whether the camera runs and takes a photo: it has started, runs without a failure and is not paused.
    var isRunning: Bool {
        session.isRunning
    }

    /// Whether a press of the Camera Control or a volume button can take a photo now: the introduction is over and a
    /// camera runs without a failure or a pause.
    var acceptsCaptureButtons: Bool {
        onboarding.step == nil && session.isRunning
    }

    /// The turn of the elements that stay upright as the phone rotates.
    var elementRotation: CameraElementRotation {
        orientation.elementRotation
    }
}
