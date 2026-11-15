//
//  FlowAcceptButton.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The check mark that hands the set over: dark on the accent while there is a set to hand over, dimmed on bare
/// glass while there is none. While the set is being handed over a spinner stands in for the check mark, and the
/// button stays lit among the controls that are disabled around it.
struct FlowAcceptButton: View {
    let isEnabled: Bool
    let isHandingOver: Bool
    let action: () -> Void

    var body: some View {
        let diameter = CameraMetrics.SideButton.diameter
        let isOnAccent = isEnabled || isHandingOver
        Button(action: action) {
            face
                .foregroundStyle(isOnAccent ? CameraPalette.onAccent : CameraPalette.label)
                .opacity(isOnAccent ? 1 : CameraPalette.unavailableOpacity)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(CameraPalette.accent).opacity(isOnAccent ? 1 : 0))
                .cameraGlass(.control)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // The button answers for itself, whatever the screen around it is: a press while the set is being handed
        // over does nothing.
        .environment(\.isEnabled, isOnAccent)
        .animation(FlowMotion.availability, value: isOnAccent)
    }

    @ViewBuilder private var face: some View {
        if isHandingOver {
            ProgressView()
                .tint(CameraPalette.onAccent)
        } else {
            FlowGlyphView(glyph: .checkmark)
                .rotatesWithDevice()
        }
    }
}
#endif
