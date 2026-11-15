//
//  PhotoCameraModel+Notices.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

// MARK: - What the camera says

extension PhotoCameraModel {
    /// What the camera says over the viewfinder now, nil when it has nothing to say: why it is paused, else why the
    /// last capture failed, else what the last photo was taken without, else what the last change of the dual camera
    /// has to say, else why saving to the photo library was refused.
    var notice: CameraNotice? {
        if let interruption = session.interruption {
            return .interrupted(interruption)
        }
        if let captureError = notices.captureError {
            return .captureFailed(captureError)
        }
        if let captureLoss = notices.captureLoss {
            return .captureLoss(captureLoss)
        }
        if let dualCameraNotice = notices.dualCameraNotice {
            return .dualCamera(dualCameraNotice)
        }
        return librarySaving?.refusal.map(CameraNotice.librarySavingRefused)
    }

    /// Clears what the camera said about the last thing that did not go as asked, with the next thing the user
    /// does. A pause is not cleared: it ends when the camera reports it.
    func clearNotices() {
        notices.clear()
        librarySaving?.clearRefusal()
    }
}
