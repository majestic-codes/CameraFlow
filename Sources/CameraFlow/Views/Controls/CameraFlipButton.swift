//
//  CameraFlipButton.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The camera flip in the top trailing corner: the glyph of the stock button, in the smaller button of the corner. It
/// is dimmed while the flow does not use the camera, before its access is granted, after a refusal and once the flow
/// ended. A finger on it readies the haptic of the flip.
struct CameraFlipButton: View {
    @Environment(\.flowLocalization) private var localization
    let layout: CameraScreenLayout
    let isEnabled: Bool
    let flipCamera: () async -> Void
    /// Readies the haptic of the flip as a finger comes down on the button.
    let onTouchDown: () -> Void

    var body: some View {
        let diameter = FlowMetrics.CornerButton.diameter
        let label = CameraControlText(localization).cameraChooser
        GlassCircleButton(diameter: diameter, onTouchDown: onTouchDown) {
            Task {
                await flipCamera()
            }
        } glyph: {
            CameraGlyphView(glyph: .flip)
                .scaleEffect(diameter / CameraMetrics.SideButton.diameter)
        }
        .disabled(!isEnabled)
        .accessibilityIdentifier(CameraIdentifier.flip)
        .accessibilityLabel(label)
        .showsLargeContent(label) {
            CameraGlyphView(glyph: .flip)
        }
        .placed(in: layout.flip)
    }
}
#endif
