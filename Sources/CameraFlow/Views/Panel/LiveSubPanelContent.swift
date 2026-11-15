//
//  LiveSubPanelContent.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Options of the Live sub-panel: On and Off, as glyphs.
///
/// The stock panel has Auto as well, which has no public API, so the row has two options. They are dimmed
/// and inert while Live Photo cannot be selected.
struct LiveSubPanelContent: View {
    @Environment(\.flowLocalization) private var localization
    let settings: PhotoSettingsModel

    var body: some View {
        SubPanelOptionGlyphRow(
            items: [
                item(isOn: true, name: "on", glyph: .livePhotoOn),
                item(isOn: false, name: "off", glyph: .livePhotoOff)
            ],
            onTouchDown: settings.optionTouched
        )
        .opacity(settings.isLivePhotoSelectable ? 1 : CameraPalette.unavailableOpacity)
        .disabled(!settings.isLivePhotoSelectable)
    }

    private func item(
        isOn: Bool,
        name: String,
        glyph: CameraGlyph
    ) -> SubPanelOptionGlyphItem<CameraGlyphView> {
        SubPanelOptionGlyphItem(
            name: name,
            label: CameraSettingSpeech(localization).switchState(isOn: isOn),
            isSelected: settings.isLivePhotoInEffect == isOn,
            glyph: CameraGlyphView(glyph: glyph, placement: .optionRow)
        ) {
            settings.select(isLivePhotoEnabled: isOn)
        }
    }
}
#endif
