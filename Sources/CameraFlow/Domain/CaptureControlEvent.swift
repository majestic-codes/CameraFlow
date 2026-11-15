//
//  CaptureControlEvent.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// How much of the screen the Camera Control's overlay takes.
enum CaptureControlsOverlay: Sendable, Equatable {
    case hidden
    /// The overlay is up and its controls take input.
    case shown
    /// The overlay shows a control at full size, and the screen keeps its own controls out of the way.
    case fullscreen
}

/// A change the user made with the Camera Control, the side button of iPhone 16 and later.
enum CaptureControlEvent: Sendable, Equatable {
    /// The zoom slider moved the camera to a displayed zoom factor.
    case zoomChanged(CGFloat)
    /// The exposure slider set the exposure bias, in stops.
    case exposureBiasChanged(Double)
    /// The lens picker chose the lens at an index of `CameraCapabilities.lenses`.
    case lensSelected(index: Int)
    case overlayChanged(CaptureControlsOverlay)
}
