//
//  CameraSettingSpeech.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// What accessibility reads for the settings, their values and their options: always in full, as the stock camera
/// speaks them, where the panel writes the short forms that fit (`CameraSettingText`).
struct CameraSettingSpeech {
    let localization: FlowLocalization

    init(_ localization: FlowLocalization) {
        self.localization = localization
    }

    // MARK: - Names

    /// The name of a setting: the label of its tile, its indicator and its sub-panel.
    func name(of setting: CameraSetting) -> String {
        switch setting {
        case .flash, .exposure, .librarySave: CameraSettingText(localization).name(of: setting)
        case .live: CameraControlText(localization).livePhoto
        case .dualCamera: CameraControlText(localization).dualCamera
        case .aspect: String(
            localized: "camera.control.aspectRatio",
            defaultValue: "Aspect ratio",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .timer: String(
            localized: "camera.control.timer",
            defaultValue: "Timer",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .format: String(
            localized: "camera.control.photoFormat",
            defaultValue: "Photo format",
            bundle: localization.bundle,
            locale: localization.locale
        )
        }
    }

    // MARK: - Voice Control

    /// What Voice Control answers to for the tile of a setting: the word under the tile, where it differs from the
    /// name, and the name.
    func tileInputLabels(of setting: CameraSetting) -> [String] {
        let word = CameraSettingText(localization).tileName(of: setting)
        let name = name(of: setting)
        return word == name ? [name] : [word, name]
    }

    /// What Voice Control answers to for the top bar indicator of a changed setting: the text it writes, where it
    /// writes one such as "RAW" or "+0.7", and its name.
    @MainActor
    func indicatorInputLabels(of setting: CameraSetting, in settings: PhotoSettingsModel) -> [String] {
        let text = CameraSettingText(localization)
        let name = name(of: setting)
        return switch setting {
        case .exposure: [text.signedStops(settings.exposureBias), name]
        case .format: [text.formatMark(format: settings.effectivePhotoFormat, quality: settings.photoQuality), name]
        case .flash, .live, .aspect, .timer, .dualCamera, .librarySave: [name]
        }
    }

    // MARK: - Values

    /// The value of a setting: the value of its tile and its indicator. Live Photo reads what the next photo takes,
    /// so a Live Photo that cannot be taken now reads off, as its tile shows it.
    @MainActor
    func value(of setting: CameraSetting, in settings: PhotoSettingsModel) -> String {
        switch setting {
        case .flash: flashMode(settings.effectiveFlashMode)
        case .live: switchState(isOn: settings.isLivePhotoInEffect)
        case .aspect: aspectRatio(settings.aspectRatio)
        case .timer: timer(settings.timer)
        case .exposure: CameraSettingText(localization).signedStops(settings.exposureBias)
        case .format:
            settings.quality.isReduced ? quality(settings.photoQuality) : settings.effectivePhotoFormat.rawValue
        case .dualCamera: switchState(isOn: settings.isDualCameraOn)
        case .librarySave: switchState(isOn: settings.isLibrarySavingOn)
        }
    }

    /// A flash mode, such as "Automatic".
    func flashMode(_ mode: CameraFlowFlashMode) -> String {
        switch mode {
        case .auto: String(
            localized: "camera.value.automatic",
            defaultValue: "Automatic",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .alwaysOn: switchState(isOn: true)
        case .off: switchState(isOn: false)
        }
    }

    func switchState(isOn: Bool) -> String {
        isOn
            ? String(
                localized: "camera.value.on.accessibility",
                defaultValue: "On",
                bundle: localization.bundle,
                locale: localization.locale
            )
            : String(
                localized: "camera.value.off.accessibility",
                defaultValue: "Off",
                bundle: localization.bundle,
                locale: localization.locale
            )
    }

    /// An aspect ratio in words, such as "4 by 3".
    func aspectRatio(_ ratio: CameraFlowAspectRatio) -> String {
        switch ratio {
        case .fourByThree: String(
            localized: "camera.aspect.fourByThree.accessibility",
            defaultValue: "4 by 3",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .sixteenByNine: String(
            localized: "camera.aspect.sixteenByNine.accessibility",
            defaultValue: "16 by 9",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .square: String(
            localized: "camera.aspect.square.accessibility",
            defaultValue: "Square",
            bundle: localization.bundle,
            locale: localization.locale
        )
        }
    }

    /// A self-timer delay, such as "3 seconds".
    func timer(_ timer: CameraFlowTimer) -> String {
        guard timer != .off else {
            return switchState(isOn: false)
        }
        let seconds = timer.rawValue
        return String(
            localized: "camera.option.seconds",
            defaultValue: "\(seconds) seconds",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    func quality(_ quality: CameraFlowQuality) -> String {
        switch quality {
        case .high: String(
            localized: "camera.quality.high.accessibility",
            defaultValue: "High",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .medium: String(
            localized: "camera.quality.medium.accessibility",
            defaultValue: "Medium",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .low: String(
            localized: "camera.quality.low.accessibility",
            defaultValue: "Low",
            bundle: localization.bundle,
            locale: localization.locale
        )
        }
    }
}
