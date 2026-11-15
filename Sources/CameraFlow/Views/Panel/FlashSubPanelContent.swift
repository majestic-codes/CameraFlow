//
//  FlashSubPanelContent.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Options of the Flash sub-panel: Auto, On, Off, as glyphs. They are dimmed and inert while the running camera offers
/// no flash.
struct FlashSubPanelContent: View {
    @Environment(\.flowLocalization) private var localization
    let settings: PhotoSettingsModel

    var body: some View {
        SubPanelOptionGlyphRow(items: items, onTouchDown: settings.optionTouched)
            .opacity(settings.isFlashSelectable ? 1 : CameraPalette.unavailableOpacity)
            .disabled(!settings.isFlashSelectable)
    }

    private var items: [SubPanelOptionGlyphItem<CameraGlyphView>] {
        [
            item(.auto, name: "auto", glyph: .flashAuto),
            item(.alwaysOn, name: "on", glyph: .flashOn),
            item(.off, name: "off", glyph: .flashOff)
        ]
    }

    private func item(
        _ mode: CameraFlowFlashMode,
        name: String,
        glyph: CameraGlyph
    ) -> SubPanelOptionGlyphItem<CameraGlyphView> {
        SubPanelOptionGlyphItem(
            name: name,
            label: CameraSettingSpeech(localization).flashMode(mode),
            isSelected: settings.effectiveFlashMode == mode,
            glyph: CameraGlyphView(glyph: glyph, placement: .optionRow)
        ) {
            settings.select(flashMode: mode)
        }
    }
}
#endif
