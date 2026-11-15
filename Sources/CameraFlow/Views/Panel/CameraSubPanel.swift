//
//  CameraSubPanel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The content of the sub-panel card of one setting: a back button, the setting's title, its current value and a
/// slot with the options of that setting. The glass card itself is drawn by `ControlPanelStack`. VoiceOver starts at
/// the title as the sub-panel opens, and Escape on a hardware keyboard presses Back.
struct CameraSubPanel: View {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let panel: ControlPanelModel
    let settings: PhotoSettingsModel
    let dualCamera: DualCameraModel
    let layout: CameraScreenLayout
    let toggleDualCamera: () async -> Void
    let focus: AccessibilityFocusState<FlowFocusTarget?>.Binding
    /// Whether Back takes Escape of a hardware keyboard now.
    let takesKeyboardShortcuts: Bool

    private typealias Metrics = CameraMetrics.SubPanel

    var body: some View {
        if case let .subPanel(setting) = panel.presentation {
            let speech = CameraSettingSpeech(localization)
            ZStack(alignment: .topLeading) {
                Text(CameraSettingText(localization).title(of: setting))
                    .font(CameraTypography.subPanelTitle)
                    .tracking(CameraTypography.subPanelTitleTracking(LetterTracking(localization)))
                    .lineLimit(1)
                    .minimumScaleFactor(Metrics.textMinimumScale)
                    .accessibilityIdentifier(CameraIdentifier.subPanelTitle)
                    .accessibilityLabel(speech.name(of: setting))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused(focus, equals: .subPanelTitle)
                    .placed(in: layout.subPanelTextLine(centeredAt: Metrics.titleCenter, height: Metrics.titleHeight))
                if setting != .format {
                    Text(CameraSettingText(localization).value(of: setting, in: settings))
                        .font(CameraTypography.subPanelValue)
                        .lineLimit(1)
                        .minimumScaleFactor(Metrics.textMinimumScale)
                        .contentTransition(.numericText())
                        .accessibilityIdentifier(CameraIdentifier.subPanelValue)
                        .accessibilityLabel(speech.value(of: setting, in: settings))
                        .placed(in: layout.subPanelTextLine(
                            centeredAt: Metrics.valueCenter,
                            height: Metrics.valueHeight
                        ))
                }
                content(for: setting)
                    .placed(in: layout.subPanel)
                backButton
                    .placed(in: layout.subPanelBackTouchArea)
            }
            .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
            .turnsUpsideDownWithDevice(around: cardCenter)
            .foregroundStyle(CameraPalette.label)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(CameraIdentifier.subPanel)
            .accessibilityLabel(speech.name(of: setting))
            .accessibilityAction(.escape) { panel.showTiles() }
            .transition(.panelContent(reducesMotion: reduceMotion))
            .id(setting)
        }
    }

    /// The middle of the card in unit coordinates of the screen: the sub-panel turns upside down about it.
    private var cardCenter: UnitPoint {
        let card = layout.panelCard
        return UnitPoint(x: card.midX / layout.size.width, y: card.midY / layout.size.height)
    }

    /// Back: the circle of the stock button, which takes a touch in the larger circle a finger needs around it.
    private var backButton: some View {
        let label = CameraControlText(localization).back
        return Button(action: panel.showTiles) {
            CameraGlyphView(glyph: .back)
                .foregroundStyle(CameraPalette.label)
                .frame(width: Metrics.backButtonDiameter, height: Metrics.backButtonDiameter)
                .background(Circle().fill(CameraPalette.subPanelBackButton))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction, isActive: takesKeyboardShortcuts)
        .accessibilityIdentifier(CameraIdentifier.subPanelBack)
        .accessibilityLabel(label)
        .showsLargeContent(label) {
            CameraGlyphView(glyph: .back)
        }
    }

    @ViewBuilder
    private func content(for setting: CameraSetting) -> some View {
        switch setting {
        case .flash: FlashSubPanelContent(settings: settings)
        case .live: LiveSubPanelContent(settings: settings)
        case .aspect: AspectSubPanelContent(settings: settings)
        case .timer: TimerSubPanelContent(settings: settings)
        case .exposure: ExposureSubPanelContent(settings: settings)
        case .format: FormatSubPanelContent(settings: settings, cardWidth: layout.subPanel.width)
        case .dualCamera: DualCameraSubPanelContent(dualCamera: dualCamera, toggleDualCamera: toggleDualCamera)
        case .librarySave: LibrarySaveSubPanelContent(settings: settings)
        }
    }
}
#endif
