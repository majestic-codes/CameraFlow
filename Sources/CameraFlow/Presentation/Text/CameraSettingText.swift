//
//  CameraSettingText.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// The names, the values and the options of the settings as the control panel writes them, short where room is short.
/// Accessibility reads them in full (`CameraSettingSpeech`).
struct CameraSettingText {
    let localization: FlowLocalization

    init(_ localization: FlowLocalization) {
        self.localization = localization
    }

    // MARK: - Names

    /// The name of a setting as the panel writes it.
    func name(of setting: CameraSetting) -> String {
        switch setting {
        case .flash: String(
            localized: "camera.setting.flash",
            defaultValue: "Flash",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .live: String(
            localized: "camera.setting.live",
            defaultValue: "Live",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .aspect: String(
            localized: "camera.setting.aspect",
            defaultValue: "Aspect",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .timer: String(
            localized: "camera.setting.timer",
            defaultValue: "Timer",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .exposure: String(
            localized: "camera.setting.exposure",
            defaultValue: "Exposure",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .format: String(
            localized: "camera.setting.format",
            defaultValue: "Format",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .dualCamera: CameraControlText(localization).dualCamera
        case .librarySave: String(
            localized: "camera.setting.librarySave",
            defaultValue: "Save",
            bundle: localization.bundle,
            locale: localization.locale
        )
        }
    }

    /// The title of the sub-panel of a setting in the stock wide capitals: its name in full, the name accessibility
    /// reads.
    func title(of setting: CameraSetting) -> String {
        name(of: setting).uppercased(with: localization.locale)
    }

    /// The label under the tile of a setting in the stock wide capitals.
    func tileLabel(of setting: CameraSetting) -> String {
        tileName(of: setting).uppercased(with: localization.locale)
    }

    /// The word under the tile of a setting before it is set in capitals: its name, or the short form of a name too
    /// long for a tile.
    func tileName(of setting: CameraSetting) -> String {
        switch setting {
        case .dualCamera: String(
            localized: "camera.setting.dualCamera",
            defaultValue: "Dual",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .flash, .live, .aspect, .timer, .exposure, .format, .librarySave: name(of: setting)
        }
    }

    /// The label of the quality row of the Format sub-panel, in the stock wide capitals of the flow's language.
    var qualityTitle: String {
        let title = String(
            localized: "camera.setting.quality",
            defaultValue: "Quality",
            bundle: localization.bundle,
            locale: localization.locale
        )
        return title.uppercased(with: localization.locale)
    }

    // MARK: - Values

    /// The current value of a setting as its sub-panel writes it. Live Photo writes what the next photo takes, as
    /// its selected option shows it.
    @MainActor
    func value(of setting: CameraSetting, in settings: PhotoSettingsModel) -> String {
        switch setting {
        case .flash: flashMode(settings.effectiveFlashMode)
        case .live: switchState(isOn: settings.isLivePhotoInEffect)
        case .aspect: settings.aspectRatio.rawValue
        case .timer: timer(settings.timer)
        case .exposure:
            settings.displayedExposureBias.formatted(.number.precision(.fractionLength(1)).locale(localization.locale))
        case .format:
            settings.quality.isReduced ? quality(settings.photoQuality) : settings.effectivePhotoFormat.rawValue
        case .dualCamera: switchState(isOn: settings.isDualCameraOn)
        case .librarySave: switchState(isOn: settings.isLibrarySavingOn)
        }
    }

    /// Where saving puts the photos, as the Save sub-panel writes it under the options: the album by its name, or
    /// the library.
    func librarySaveDestination(_ destination: CameraFlowPhotoLibrarySaving.Destination) -> String {
        switch destination {
        case .library:
            String(
                localized: "camera.save.library",
                defaultValue: "Photo library",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case let .album(name):
            String(
                localized: "camera.save.album",
                defaultValue: "Album “\(name)”",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    /// A quality as its option of the Format sub-panel writes it.
    func quality(_ quality: CameraFlowQuality) -> String {
        switch quality {
        case .high: String(
            localized: "camera.quality.high",
            defaultValue: "High",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .medium: String(
            localized: "camera.quality.medium",
            defaultValue: "Medium",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .low: String(
            localized: "camera.quality.low",
            defaultValue: "Low",
            bundle: localization.bundle,
            locale: localization.locale
        )
        }
    }

    /// What the top bar writes in the place of a glyph for the Format setting: the format at the high quality, such
    /// as "RAW", and below it the mark of the quality, three capitals like the stock "HDR".
    func formatMark(format: CameraFlowPhotoFormat, quality: CameraFlowQuality) -> String {
        switch quality {
        case .high: format.rawValue
        case .medium: String(
            localized: "camera.quality.medium.mark",
            defaultValue: "MED",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .low: String(
            localized: "camera.quality.low.mark",
            defaultValue: "LOW",
            bundle: localization.bundle,
            locale: localization.locale
        )
        }
    }

    /// An exposure bias as a signed number of stops as the screen writes it, such as "+1.3", "-0.7" and "0.0".
    func signedStops(_ bias: Double) -> String {
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
        let displayed = PhotoSettingsModel.displayedExposureBias(bias)
        return displayed.formatted(format.sign(strategy: .always(includingZero: false)).locale(localization.locale))
    }

    func flashMode(_ mode: CameraFlowFlashMode) -> String {
        switch mode {
        case .auto: String(
            localized: "camera.value.auto",
            defaultValue: "Auto",
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
                localized: "camera.value.on",
                defaultValue: "On",
                bundle: localization.bundle,
                locale: localization.locale
            )
            : String(
                localized: "camera.value.off",
                defaultValue: "Off",
                bundle: localization.bundle,
                locale: localization.locale
            )
    }

    /// A self-timer delay as the Timer sub-panel writes it, such as "3s".
    func timer(_ timer: CameraFlowTimer) -> String {
        guard timer != .off else {
            return switchState(isOn: false)
        }
        let seconds = timer.rawValue
        return String(
            localized: "camera.value.seconds",
            defaultValue: "\(seconds)s",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The megapixel count of the photos in the digits of the locale, as the Format tile writes it.
    func megapixelCount(_ megapixels: Int) -> String {
        megapixels.formatted(.number.locale(localization.locale))
    }

    /// The seconds left on the self-timer in the digits of the locale, as the countdown writes and reads them.
    func countdown(_ seconds: Int) -> String {
        seconds.formatted(.number.locale(localization.locale))
    }

    /// The line under the options of the Format sub-panel: the approximate size of the file of one photo,
    /// such as "About 2.1 MB per photo." The size is rounded to two digits, since it is an estimate, and written
    /// in the units and with the decimal separator of the locale.
    func photoSizeFootnote(byteCount: Int) -> String {
        let rounded = roundedToTwoDigits(byteCount)
        let size = rounded.formatted(.byteCount(style: .file).locale(localization.locale))
        return String(
            localized: "camera.format.photoSize",
            defaultValue: "About \(size) per photo.",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    private func roundedToTwoDigits(_ byteCount: Int) -> Int {
        var step = 1
        while byteCount / step >= 100 {
            step *= 10
        }
        return (byteCount + step / 2) / step * step
    }
}
