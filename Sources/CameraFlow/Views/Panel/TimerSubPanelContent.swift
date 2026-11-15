//
//  TimerSubPanelContent.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Options of the Timer sub-panel: Off, 3, 5, 10 seconds, as glyphs.
struct TimerSubPanelContent: View {
    @Environment(\.flowLocalization) private var localization
    let settings: PhotoSettingsModel

    var body: some View {
        SubPanelOptionGlyphRow(
            items: items,
            pitch: CameraMetrics.SubPanel.timerOptionPitch,
            onTouchDown: settings.optionTouched
        )
    }

    private var items: [SubPanelOptionGlyphItem<CameraGlyphView>] {
        CameraFlowTimer.allCases.map { timer in
            let name = timer == .off ? "off" : "\(timer.rawValue)s"
            return SubPanelOptionGlyphItem(
                name: name,
                label: CameraSettingSpeech(localization).timer(timer),
                isSelected: settings.timer == timer,
                glyph: CameraGlyphView(glyph: CameraGlyph(timer: timer), placement: .optionRow),
                visibleText: timer == .off ? nil : String(timer.rawValue)
            ) {
                settings.select(timer: timer)
            }
        }
    }
}
#endif
