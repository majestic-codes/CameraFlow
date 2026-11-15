//
//  LibrarySaveSubPanelContent.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI
import UIKit

/// Options of the Save sub-panel: On and Off, as words, with where the photos go written under them.
///
/// Switching on asks for library access when the library has not been asked yet. When access is refused the
/// option stays Off and the notice over the viewfinder says why. While the user can grant the access in the app's
/// page of Settings, the way there stands in the place of the destination, as it does under a refused camera.
struct LibrarySaveSubPanelContent: View {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityShowButtonShapes) private var showsButtonShapes
    @Environment(\.colorSchemeContrast) private var contrast
    let settings: PhotoSettingsModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            SubPanelOptionGlyphRow(
                items: [item(isOn: true, name: "on"), item(isOn: false, name: "off")],
                pitch: CameraMetrics.SubPanel.wordOptionPitch,
                onTouchDown: settings.optionTouched
            )
            if let saving = settings.librarySaving {
                SubPanelOptionCanvas {
                    if let settingsURL = settingsURL(for: saving) {
                        settingsButton(settingsURL)
                            .subPanelCentered(baseline: CameraMetrics.SubPanel.destinationBaseline)
                    } else {
                        Text(CameraSettingText(localization).librarySaveDestination(saving.destination))
                            .font(CameraTypography.formatFootnote)
                            .foregroundStyle(CameraPalette.label.opacity(footnoteOpacity))
                            .subPanelCentered(baseline: CameraMetrics.SubPanel.destinationBaseline)
                    }
                }
            }
        }
    }

    /// The app's page of Settings while the user can grant the access there, nil otherwise.
    private func settingsURL(for saving: PhotoLibrarySavingModel) -> URL? {
        guard saving.isRefusalLiftedInSettings else { return nil }
        return URL(string: UIApplication.openSettingsURLString)
    }

    private var footnoteOpacity: Double {
        contrast == .increased ? CameraPalette.formatFootnoteIncreasedOpacity : CameraPalette.formatFootnoteOpacity
    }

    private func settingsButton(_ settingsURL: URL) -> some View {
        let title = CameraNoticeText(localization).openSettings
        return Button {
            openURL(settingsURL)
        } label: {
            Text(title)
                .font(CameraTypography.formatOption)
                .foregroundStyle(CameraPalette.accent)
                .underline(showsButtonShapes)
                .frame(minHeight: CameraMetrics.SubPanel.optionHitHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(CameraIdentifier.subPanelLibrarySettings)
        .showsLargeContent(title)
    }

    private func item(isOn: Bool, name: String) -> SubPanelOptionGlyphItem<Text> {
        let visible = CameraSettingText(localization).switchState(isOn: isOn)
        return SubPanelOptionGlyphItem(
            name: name,
            label: CameraSettingSpeech(localization).switchState(isOn: isOn),
            isSelected: settings.isLibrarySavingOn == isOn,
            glyph: Text(visible).font(CameraTypography.formatOption).underline(showsButtonShapes),
            visibleText: visible
        ) {
            Task { await settings.select(isLibrarySavingEnabled: isOn) }
        }
    }
}
#endif
