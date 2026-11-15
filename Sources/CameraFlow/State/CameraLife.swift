//
//  CameraLife.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Where the camera of a flow is in its life. It is active once its access is granted, until the flow stops it on
/// purpose or closes it for good. A camera that was refused or closed never starts again.
enum CameraLife: Equatable {
    /// Not started yet: its access has not been asked for, or the answer has not come.
    case waiting
    /// The access was refused, or the device has no camera.
    case refused
    /// Started and used by the flow, also while it fails or is paused.
    case active
    /// Stopped on purpose, under the review, until it is resumed.
    case stopped
    /// Closed for good, once the flow ended.
    case closed
}
