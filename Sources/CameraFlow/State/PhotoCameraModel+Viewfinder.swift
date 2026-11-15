//
//  PhotoCameraModel+Viewfinder.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

// MARK: - Touches on the viewfinder

extension PhotoCameraModel {

    /// A tap on the viewfinder closes the control panel when it is open, and focuses a camera that runs otherwise.
    func viewfinderTapped(atUnitPoint unitPoint: CGPoint, devicePoint: CGPoint) {
        guard !panel.isOpen else {
            panel.dismiss()
            return
        }
        guard session.isRunning else { return }
        focus.focus(atUnitPoint: unitPoint, devicePoint: devicePoint)
    }

    /// A vertical drag began on the viewfinder. It changes the exposure under the reticle, and puts the reticle where
    /// the finger went down when none is shown. Returns whether the drag changes the exposure: it does not while
    /// the control panel is open, when the app fixed the exposure, nor over a camera that does not run.
    func beginExposureDrag(atUnitPoint unitPoint: CGPoint, devicePoint: CGPoint) -> Bool {
        guard !panel.isOpen, settings.isExposureAdjustable, session.isRunning else { return false }
        if focus.reticle == nil {
            focus.focus(atUnitPoint: unitPoint, devicePoint: devicePoint)
        }
        focus.beginAdjustingExposure()
        return focus.isAdjustingExposure
    }

    /// Sets the exposure bias the drag has reached, for as long as the drag holds the reticle.
    func changeExposure(to bias: Double) {
        guard focus.isAdjustingExposure, bias != settings.exposureBias else { return }
        settings.setExposureBias(bias)
    }

    func endExposureDrag() {
        focus.endAdjustingExposure()
    }

    /// Moves the exposure bias by a step from the adjustable element of the reticle, which keeps the reticle on
    /// screen for its lifetime again. A bias the app fixed stays as it is.
    func adjustExposure(by step: Double) {
        settings.stepExposureBias(by: step)
        focus.exposureAdjusted()
    }
}
