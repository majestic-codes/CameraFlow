//
//  CaptureReadiness.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// How ready the camera is to take another photo, as its photo output reports it. A photo asked for while the camera
/// is not ready is still taken, only later.
enum CaptureReadiness: Sendable, Equatable {
    /// The camera does not run.
    case notRunning
    /// The camera takes another photo at once.
    case ready
    /// The camera is busy for a moment, as between quick shots.
    case notReadyMomentarily
    /// The camera is busy taking the photos asked for, such as one with the flash.
    case waitingForCapture
    /// The camera is busy processing the photos it took.
    case waitingForProcessing

    /// The readiness of two cameras that take one photo together, as the back and the front camera of the pair do:
    /// ready only when both are, and otherwise as far from ready as the one further from it.
    func combined(with other: Self) -> Self {
        distanceFromReady >= other.distanceFromReady ? self : other
    }

    /// How far the camera is from taking another photo at once. A camera that does not run is the furthest.
    private var distanceFromReady: Int {
        switch self {
        case .ready: 0
        case .notReadyMomentarily: 1
        case .waitingForCapture: 2
        case .waitingForProcessing: 3
        case .notRunning: 4
        }
    }
}
