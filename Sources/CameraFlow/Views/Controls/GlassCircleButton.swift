//
//  GlassCircleButton.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// A round glass button with a white glyph, the building block of the buttons around the shutter, in the top
/// corners and in the bottom bar. The glyph dims while the button is disabled.
struct GlassCircleButton<Glyph: View>: View {
    let diameter: CGFloat
    /// The circle the button takes a touch in, around the glass: a button drawn smaller than a finger needs takes
    /// it in a larger one. Never smaller than the glass.
    var touchDiameter: CGFloat = 0
    /// What a finger coming down on the button readies, such as the haptic of its action. Nothing by default.
    var onTouchDown: () -> Void = {}
    let action: () -> Void
    @ViewBuilder let glyph: () -> Glyph

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let touch = max(diameter, touchDiameter)
        Button(action: action) {
            glyph()
                .foregroundStyle(CameraPalette.label)
                .opacity(isEnabled ? 1 : CameraPalette.unavailableOpacity)
                .rotatesWithDevice()
                .frame(width: diameter, height: diameter)
                .cameraGlass(.control)
                .frame(width: touch, height: touch)
                .contentShape(Circle())
        }
        .buttonStyle(TouchDownButtonStyle(onTouchDown: onTouchDown))
        .animation(FlowMotion.availability, value: isEnabled)
    }
}
#endif
