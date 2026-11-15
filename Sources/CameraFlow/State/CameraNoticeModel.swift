//
//  CameraNoticeModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation

/// What the camera said about the last thing that did not go as asked: why the last capture failed, what the last
/// photo was taken without and what the last change of the dual camera has to say. `PhotoCameraModel` posts them and
/// clears them with the next thing the user does.
@MainActor
@Observable
final class CameraNoticeModel {
    /// Why the last capture failed.
    private(set) var captureError: CameraServiceError?
    /// What the last photo was taken without, when a part of its capture failed.
    private(set) var captureLoss: CapturedPhotoLoss?
    /// What the last change of the dual camera has to say.
    private(set) var dualCameraNotice: DualCameraNotice?

    func captureFailed(with error: CameraServiceError) {
        captureError = error
    }

    func showCaptureLossNotice(_ loss: CapturedPhotoLoss) {
        captureLoss = loss
    }

    func showDualCameraNotice(_ notice: DualCameraNotice) {
        dualCameraNotice = notice
    }

    func clear() {
        captureError = nil
        captureLoss = nil
        dualCameraNotice = nil
    }
}
