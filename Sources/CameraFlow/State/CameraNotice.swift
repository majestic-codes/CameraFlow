//
//  CameraNotice.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The one thing the camera says over the viewfinder, as `PhotoCameraModel.notice` picks it.
enum CameraNotice: Equatable {
    /// The session is paused. It comes first: it is what the user can act on.
    case interrupted(CameraInterruption)
    /// The last capture failed.
    case captureFailed(CameraServiceError)
    /// The last photo was handed over without a part of its capture that failed.
    case captureLoss(CapturedPhotoLoss)
    /// What the last change of the dual camera has to say.
    case dualCamera(DualCameraNotice)
    /// Saving to the photo library could not be switched on, or the library refused the introduction.
    case librarySavingRefused(CameraFlowPhotoLibrarySaveFailure)
}
