//
//  ControlPanelTileFace.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// What a tile circle shows for the current value of its setting, the way the stock tiles do: the light cut of
/// the state glyph for flash, Live, aspect, timer, the circle and an unset exposure, text for a set exposure and the
/// format, and the system's saving symbol for Save, dimmed while saving is off. Flash and Live are dimmed while they
/// cannot be selected.
struct ControlPanelTileFace: View {
    @Environment(\.flowLocalization) private var localization
    let setting: CameraSetting
    let settings: PhotoSettingsModel

    var body: some View {
        content
            .foregroundStyle(CameraPalette.label)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch setting {
        case .flash:
            glyph(CameraGlyph(flashMode: settings.effectiveFlashMode))
                .opacity(settings.isFlashSelectable ? 1 : CameraPalette.unavailableOpacity)
        case .live:
            glyph(CameraGlyph(isLivePhotoOn: settings.isLivePhotoInEffect))
                .opacity(settings.isLivePhotoSelectable ? 1 : CameraPalette.unavailableOpacity)
        case .aspect:
            glyph(CameraGlyph(aspectRatio: settings.aspectRatio))
        case .timer:
            glyph(CameraGlyph(timer: settings.timer))
        case .exposure:
            if settings.displayedExposureBias == 0 {
                glyph(.exposure)
            } else {
                Text(CameraSettingText(localization).value(of: .exposure, in: settings))
                    .font(CameraTypography.tileValue)
            }
        case .format:
            VStack(spacing: 0) {
                Text(settings.effectivePhotoFormat.rawValue)
                    .font(CameraTypography.formatTileFormat)
                let megapixels = settings.effectivePhotoFrame?.megapixels ?? PhotoCaptureResolution.preferredMegapixels
                Text(CameraSettingText(localization).megapixelCount(megapixels))
                    .font(CameraTypography.formatTileMegapixels)
            }
        case .dualCamera:
            DualCameraGlyphView(
                hasCircle: settings.isDualCameraOn,
                pointSize: CameraMetrics.Symbol.regularPointSize,
                weight: .light
            )
        case .librarySave:
            FlowSymbolView(symbol: .librarySave, pointSize: CameraMetrics.Symbol.regularPointSize, weight: .light)
                .opacity(settings.isLibrarySavingOn ? 1 : CameraPalette.unavailableOpacity)
        }
    }

    private func glyph(_ glyph: CameraGlyph) -> some View {
        CameraGlyphView(glyph: glyph, placement: .tile)
    }
}
#endif
