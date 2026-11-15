//
//  LensZoomButton.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// One lens button: the factor, on a glass circle while it is the active lens. A press shrinks the factor.
struct LensZoomButton: View {
    let title: String
    let isActive: Bool
    let isPressed: Bool

    var body: some View {
        let diameter = CameraMetrics.LensRow.buttonDiameter
        ZStack {
            Color.clear
                .frame(width: diameter, height: diameter)
                .cameraGlass(.overPreview)
                .compositingGroup()
                .animation(isActive ? CameraMotion.Lens.circleFadeIn : CameraMotion.Lens.circleOut) { content in
                    content.opacity(isActive ? 1 : 0)
                }
            LensZoomTitle(title: title, isActive: isActive)
                .animation(CameraMotion.Lens.press) { content in
                    content.scaleEffect(isPressed ? CameraMotion.Lens.pressedScale : 1)
                }
        }
        .frame(width: diameter, height: diameter)
    }
}

/// The text of a lens button: yellow with a soft shadow while active, white with a tight one otherwise.
///
/// The text and its colour change at once. Only the shadow follows the selection animation.
struct LensZoomTitle: View {
    let title: String
    let isActive: Bool

    var body: some View {
        let metrics = CameraMetrics.LensRow.self
        let diameter = metrics.buttonDiameter
        Text(title)
            .font(CameraTypography.zoomFactor)
            .kerning(CameraTypography.zoomFactorKerning)
            .foregroundStyle(isActive ? CameraPalette.accent : CameraPalette.label)
            .fixedSize()
            .frame(width: diameter, height: diameter)
            .rotatesWithDevice()
            .animation(CameraMotion.Lens.circleOut) { content in
                content.shadow(
                    color: isActive ? CameraPalette.activeLensShadow : CameraPalette.lensShadow,
                    radius: isActive ? metrics.activeShadowRadius : metrics.shadowRadius
                )
            }
    }
}
#endif
