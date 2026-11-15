//
//  DualCameraSubPanelContent.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Options of the sub-panel of the second camera's circle: On and Off, as glyphs, like the Live sub-panel. They are
/// dimmed and inert while the circle cannot be switched.
struct DualCameraSubPanelContent: View {
    @Environment(\.flowLocalization) private var localization
    let dualCamera: DualCameraModel
    let toggleDualCamera: () async -> Void

    var body: some View {
        SubPanelOptionGlyphRow(items: [
            item(isOn: true, name: "on"),
            item(isOn: false, name: "off")
        ])
        .opacity(dualCamera.isToggleEnabled ? 1 : CameraPalette.unavailableOpacity)
        .disabled(!dualCamera.isToggleEnabled)
    }

    private func item(isOn: Bool, name: String) -> SubPanelOptionGlyphItem<DualCameraGlyphView> {
        SubPanelOptionGlyphItem(
            name: name,
            label: CameraSettingSpeech(localization).switchState(isOn: isOn),
            isSelected: dualCamera.isOn == isOn,
            glyph: DualCameraGlyphView(hasCircle: isOn, pointSize: CameraMetrics.Symbol.regularPointSize)
        ) {
            guard dualCamera.isOn != isOn else { return }
            Task {
                await toggleDualCamera()
            }
        }
    }
}
#endif
