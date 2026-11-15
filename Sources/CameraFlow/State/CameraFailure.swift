//
//  CameraFailure.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Why the camera does not run.
enum CameraFailure: Equatable {
    /// The user refused the camera, now or earlier.
    case accessDenied
    /// A device policy, such as Screen Time or a profile, blocks the camera.
    case accessRestricted
    /// The camera could not be started.
    case unavailable(CameraServiceError)
    /// The running session stopped with an error. The system's words for it go to the log, not to the screen.
    case stopped

    /// Whether starting the camera again may help, so the screen offers it. Access is granted in Settings only, a
    /// restriction is lifted by whoever set it, and a device without a camera never gets one.
    var isRetryable: Bool {
        switch self {
        case .accessDenied, .accessRestricted, .unavailable(.noCamera): false
        case .unavailable, .stopped: true
        }
    }

    /// Whether the user can lift the failure on the app's page of Settings. A restriction is not the user's to lift.
    var isLiftedInSettings: Bool {
        self == .accessDenied
    }
}
