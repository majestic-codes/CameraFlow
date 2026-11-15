//
//  CaptureControlsModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation

/// The Camera Control's overlay over the screen, as the running camera reports it.
@MainActor
@Observable
final class CaptureControlsModel {
    /// How much of the screen the overlay takes.
    private(set) var overlay = CaptureControlsOverlay.hidden

    /// Whether the screen keeps the lens row, the dial and the control panel out of the way of the overlay.
    var hidesControls: Bool {
        overlay == .fullscreen
    }

    func overlayChanged(to overlay: CaptureControlsOverlay) {
        self.overlay = overlay
    }
}
