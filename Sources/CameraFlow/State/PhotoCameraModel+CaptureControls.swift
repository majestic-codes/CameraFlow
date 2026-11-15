//
//  PhotoCameraModel+CaptureControls.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

extension PhotoCameraModel {

    /// The zoom and the exposure bias come already applied to the camera. A lens picked there is zoomed to here.
    func handle(_ event: CaptureControlEvent) {
        switch event {
        case let .zoomChanged(factor):
            zoom.factorChanged(to: factor)
        case let .exposureBiasChanged(bias):
            settings.exposureBiasChanged(to: bias)
        case let .lensSelected(index):
            zoom.selectLens(at: index)
        case let .overlayChanged(overlay):
            captureControls.overlayChanged(to: overlay)
        }
    }
}
