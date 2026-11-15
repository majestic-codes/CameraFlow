//
//  PhotoCameraModel+PinchZoom.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

// MARK: - Pinch on the viewfinder

extension PhotoCameraModel {
    /// Whether a pinch on the viewfinder zooms now: a camera runs without a failure or a pause, the introduction is
    /// over, and the zoom control shows, which the grid of tiles and the Camera Control's overlay hide.
    var acceptsPinchZoom: Bool {
        guard session.isRunning, onboarding.step == nil else { return false }
        return panel.presentation != .tiles && !captureControls.hidesControls
    }
}
