//
//  DualCameraNotice.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the screen says about the second camera's circle when it comes on with less than the user chose, or goes.
enum DualCameraNotice: Sendable, Equatable {
    /// A chosen setting the camera of the viewfinder cannot keep in the pair. It comes back with the circle off.
    case settingOff(DualCameraSetting)
    /// The system pressure got too high for two cameras, so the circle went off.
    case turnedOffUnderPressure
    /// The two cameras cannot run together now.
    case unavailable
}

/// A setting of the next photo that the camera of the viewfinder does not offer in the pair.
enum DualCameraSetting: Sendable, Equatable {
    case livePhoto
    case raw
    /// The preferred size of 12 MP: the pair shoots at a smaller one.
    case resolution
    case flash
}
