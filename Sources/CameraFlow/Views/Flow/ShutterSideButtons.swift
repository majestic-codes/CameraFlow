//
//  ShutterSideButtons.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The buttons beside the shutter: the photo library on its left, in a flow that offers it, and "more" on its
/// right, in a flow with a setting the user may change.
///
/// The buttons fade out, stop taking touches and are hidden from accessibility while the control panel is open,
/// because its card covers them.
struct ShutterSideButtons: View {
    @Environment(\.flowLocalization) private var localization
    let flow: EmbeddedCameraFlowModel
    let panel: ControlPanelModel
    let layout: CameraScreenLayout
    let focus: AccessibilityFocusState<FlowFocusTarget?>.Binding

    var body: some View {
        let diameter = CameraMetrics.SideButton.diameter
        ZStack(alignment: .topLeading) {
            if flow.isLibraryPickerEnabled {
                GlassCircleButton(diameter: diameter, action: flow.openLibrary) {
                    FlowGlyphView(glyph: .library)
                }
                .disabled(!flow.canOpenLibrary)
                .accessibilityIdentifier(FlowIdentifier.library)
                .accessibilityLabel(FlowText(localization).photoLibrary)
                .showsLargeContent(FlowText(localization).photoLibrary)
                .placed(in: layout.library)
            }
            if !panel.settings.isEmpty {
                GlassCircleButton(diameter: diameter, action: panel.showTiles) {
                    CameraGlyphView(glyph: .more)
                }
                .accessibilityIdentifier(CameraIdentifier.more)
                .accessibilityLabel(CameraControlText(localization).cameraControls)
                .accessibilityFocused(focus, equals: .cameraControls)
                .showsLargeContent(CameraControlText(localization).cameraControls)
                .placed(in: layout.more)
            }
        }
        .concealed(panel.isOpen)
    }
}
#endif
