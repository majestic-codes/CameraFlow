//
//  AspectSubPanelContent.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Options of the Aspect sub-panel: 4:3, 16:9, 1:1, as glyphs.
struct AspectSubPanelContent: View {
    @Environment(\.flowLocalization) private var localization
    let settings: PhotoSettingsModel

    var body: some View {
        SubPanelOptionGlyphRow(items: items, onTouchDown: settings.optionTouched)
    }

    private var items: [SubPanelOptionGlyphItem<CameraGlyphView>] {
        CameraFlowAspectRatio.allCases.map { ratio in
            SubPanelOptionGlyphItem(
                name: ratio.rawValue,
                label: CameraSettingSpeech(localization).aspectRatio(ratio),
                isSelected: settings.aspectRatio == ratio,
                glyph: CameraGlyphView(glyph: CameraGlyph(aspectRatio: ratio), placement: .optionRow),
                visibleText: ratio.rawValue
            ) {
                settings.select(aspectRatio: ratio)
            }
        }
    }
}
#endif
