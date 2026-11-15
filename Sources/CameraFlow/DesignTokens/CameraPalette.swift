//
//  CameraPalette.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import SwiftUI

/// Colours of the stock Photo camera.
enum CameraPalette {
    static let background = Color.black
    static let accent = Color(red: 1, green: 214.0 / 255.0, blue: 0)
    static let label = Color.white
    static let shutterDisc = Color.white
    /// Fill a glass button reads as over black.
    static let glassFill = Color(white: 31.0 / 255.0)
    /// Shade over the system glass that brings it to the stock readings over the preview: 31 over black,
    /// 37 35 34 over a dark preview of 15 11 9 and 97 85 69 over a bright one of 175 150 122.
    static let glassPreviewShade = Color(white: 0.11).opacity(0.522)
    /// Tint laid over the blurred backdrop where the system glass is unavailable.
    static let glassImitationTint = glassFill.opacity(0.33)
    /// Fill of a tile circle in the control panel.
    static let panelTile = Color.black.opacity(0.4)
    static let panelGrabber = Color.white.opacity(0.3)
    /// The grabber with Increase Contrast on: 3.8 to 1 over the card on a bright scene, where 0.3 gives 2.1 to 1.
    static let panelGrabberIncreased = Color.white.opacity(0.6)
    static let dialDisc = Color.black.opacity(0.5)
    static let dialMinorLabel = Color.white.opacity(0.3)
    /// The focal lengths of the dial with Increase Contrast on: 10 to 1 over the disc on a dark scene, where 0.3
    /// gives 2.5 to 1.
    static let dialMinorLabelIncreased = Color.white.opacity(0.7)
    static let focusReticle = accent
    /// Opacity of an option the running camera cannot use.
    static let unavailableOpacity = 0.35
    /// The opacity of a whole button while a finger is on it, and of a disabled one, over what its own label shows:
    /// the system's plain button style dims a button so, measured on macOS 27.
    static let pressedButtonOpacity = 0.75
    static let disabledButtonOpacity = 0.5
    /// Tile labels read 230 of 255 over the card on the phone.
    static let tileLabelOpacity = 0.89
    static let formatFootnoteOpacity = 0.5
    /// The footnotes of the sub-panels with Increase Contrast on: 5.8 to 1 over the card on a bright scene, where 0.5
    /// gives 3.1 to 1.
    static let formatFootnoteIncreasedOpacity = 0.85
    /// The pill of the selected mode in the mode switch, which reads 44 of 255 over the capsule's 22.
    static let selectedSegment = Color.white.opacity(0.1)
    static let selectedSegmentRim = Color.white.opacity(0.16)
    /// The glyph on the accent fill of the check mark and the count on the badge.
    static let onAccent = Color.black
    /// The rim of the small copy of a fresh photo and of a tile of the review strip.
    static let photoRim = Color.white.opacity(0.25)
    /// The "+" tile of the review strip.
    static let addTile = Color(white: 44.0 / 255.0)
    /// The outline that parts the dot of a drawing from the photo under it.
    static let drawingMarkOutline = Color.black
    /// The rim of the second camera's circle, which a composited photo draws the same.
    static let dualCameraRim = Color.white.opacity(FlowMetrics.DualCameraCircle.rimOpacity)
    static let dualCameraShadow = Color.black.opacity(FlowMetrics.DualCameraCircle.shadowOpacity)
    /// The circle of the back button of a sub-panel, which reads 26 over the card's 33 on the phone.
    static let subPanelBackButton = Color.black.opacity(0.21)
    /// The shadows under the countdown digits and under the factors of the lens buttons.
    static let countdownShadow = Color.black.opacity(CameraMetrics.Countdown.shadowOpacity)
    static let activeLensShadow = Color.black.opacity(CameraMetrics.LensRow.activeShadowOpacity)
    static let lensShadow = Color.black.opacity(CameraMetrics.LensRow.shadowOpacity)

    // MARK: - Shutter

    /// How the ring around the shutter disc catches the light: white opacities at even steps clockwise from the
    /// top, of the glow across the band and of its rim.
    static let shutterGlow: [Double] = [1, 0.55, 0.13, 0, 0, 0.35, 1, 0.35, 0, 0, 0.13, 0.55, 1]
    static let shutterRim: [Double] = [0.64, 0.35, 0.21, 0.11, 0.11, 0.29, 0.42, 0.29, 0.11, 0.09, 0.21, 0.35, 0.64]
    /// The white of the glow across the band at the top of the ring, from the disc out to the rim.
    static let shutterGlowStops: [Gradient.Stop] = [
        .init(color: .white.opacity(0.013), location: 0),
        .init(color: .white.opacity(0.027), location: 0.33),
        .init(color: .white.opacity(0.05), location: 0.55),
        .init(color: .white.opacity(0.07), location: 0.67),
        .init(color: .white.opacity(0.10), location: 0.8),
        .init(color: .white.opacity(0.10), location: 1)
    ]
}
