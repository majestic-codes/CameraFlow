//
//  CameraControlPanel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The content of the control panel card: the grabber and one tile per setting. A tile opens the sub-panel of its
/// setting. The view is the size of the card and lays its parts out from the card's corner, so its accessibility
/// frame is the card and the tiles are its children. The glass card itself is drawn by `ControlPanelStack`, shared
/// with the sub-panel so that one morphs into the other.
///
/// VoiceOver starts at the first tile as the tiles open, and at the tile of the sub-panel it comes back from.
struct CameraControlPanel: View {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let panel: ControlPanelModel
    let settings: PhotoSettingsModel
    let dualCamera: DualCameraModel
    let layout: CameraScreenLayout
    let focus: AccessibilityFocusState<FlowFocusTarget?>.Binding

    private typealias Metrics = CameraMetrics.ControlPanel

    var body: some View {
        if panel.presentation == .tiles {
            let card = layout.controlPanel
            ZStack(alignment: .topLeading) {
                Color.clear
                Capsule()
                    .fill(contrast == .increased ? CameraPalette.panelGrabberIncreased : CameraPalette.panelGrabber)
                    .accessibilityHidden(true)
                    .placed(in: Self.local(layout.controlPanelGrabber, in: card))
                ForEach(Array(panel.settings.enumerated()), id: \.element) { index, setting in
                    tile(for: setting)
                        .scaleEffect(layout.controlPanelScale)
                        .placed(in: Self.local(layout.controlPanelTile(at: index), in: card))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(CameraIdentifier.panel)
            .accessibilityLabel(CameraControlText(localization).cameraControls)
            .accessibilityAction(.escape) { panel.dismiss() }
            .placed(in: card)
            .transition(.panelContent(reducesMotion: reduceMotion))
        }
    }

    /// A frame in screen coordinates moved into the coordinates of the card.
    private static func local(_ frame: CGRect, in card: CGRect) -> CGRect {
        frame.offsetBy(dx: -card.minX, dy: -card.minY)
    }

    private func tile(for setting: CameraSetting) -> some View {
        let speech = CameraSettingSpeech(localization)
        let name = speech.name(of: setting)
        let face = ControlPanelTileFace(setting: setting, settings: settings)
        return Button {
            panel.showSubPanel(setting)
        } label: {
            VStack(spacing: 0) {
                face
                    .frame(width: Metrics.tileCircleDiameter, height: Metrics.tileCircleDiameter)
                    .background(Circle().fill(CameraPalette.panelTile))
                Text(CameraSettingText(localization).tileLabel(of: setting))
                    .font(CameraTypography.tileLabel)
                    .tracking(CameraTypography.tileLabelTracking(LetterTracking(localization)))
                    .foregroundStyle(CameraPalette.label.opacity(CameraPalette.tileLabelOpacity))
                    .lineLimit(1)
                    .minimumScaleFactor(Metrics.labelMinimumScale)
                    .frame(width: layout.controlPanelTileLabelWidth, height: Metrics.labelHeight)
                    .padding(.top, labelTop)
                Spacer(minLength: 0)
            }
            .frame(width: Metrics.tileSize.width, height: Metrics.tileSize.height)
            .rotatesWithDevice()
            .contentShape(Rectangle())
        }
        .buttonStyle(TouchDownButtonStyle(onTouchDown: panel.tileTouched))
        .disabled(!isTileEnabled(setting))
        .accessibilityIdentifier(CameraIdentifier.panelTile(setting))
        .accessibilityLabel(name)
        .accessibilityValue(speech.value(of: setting, in: settings))
        .accessibilityInputLabels(speech.tileInputLabels(of: setting))
        .accessibilityFocused(focus, equals: .panelTile(setting))
        .showsLargeContent(name) {
            face
        }
    }

    /// Flash and Live are inert while they cannot be selected, and the circle once the device cannot run two cameras.
    private func isTileEnabled(_ setting: CameraSetting) -> Bool {
        switch setting {
        case .flash: settings.isFlashSelectable
        case .live: settings.isLivePhotoSelectable
        case .dualCamera: dualCamera.isToggleOffered
        case .aspect, .timer, .exposure, .format, .librarySave: true
        }
    }

    /// Gap between the circle and the label line, so that the label capitals sit where the stock ones do.
    private var labelTop: CGFloat {
        Metrics.labelBelowCircleCenter - Metrics.tileCircleDiameter / 2 - Metrics.labelHeight / 2
    }
}
#endif
