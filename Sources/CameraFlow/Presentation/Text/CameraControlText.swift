//
//  CameraControlText.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// What accessibility reads for the controls of the camera screen, and the words of the zoom dial.
struct CameraControlText {
    let localization: FlowLocalization

    init(_ localization: FlowLocalization) {
        self.localization = localization
    }

    /// The "more" button and the control panel it opens.
    var cameraControls: String {
        String(
            localized: "camera.control.more",
            defaultValue: "Camera controls",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The grabber of the control panel, which closes the panel.
    var dismissControls: String {
        String(
            localized: "camera.control.dismissControls",
            defaultValue: "Dismiss camera controls",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var cameraChooser: String {
        String(
            localized: "camera.control.flip",
            defaultValue: "Camera chooser",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var livePhoto: String {
        String(
            localized: "camera.control.livePhoto",
            defaultValue: "Live Photo",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The toggle of the circle with the second camera, and its setting.
    var dualCamera: String {
        String(
            localized: "camera.control.dualCamera",
            defaultValue: "Dual Capture",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The circle in the viewfinder, named after the camera it shows.
    func dualCameraCircle(showing position: CameraPosition) -> String {
        switch position {
        case .front:
            String(
                localized: "camera.control.dualCameraCircle",
                defaultValue: "Front camera",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .back:
            String(
                localized: "camera.control.dualCameraCircle.back",
                defaultValue: "Back camera",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    /// The shutter: it takes a photo, or stops the self-timer while it counts down.
    func shutter(isCountingDown: Bool) -> String {
        isCountingDown
            ? String(
                localized: "camera.control.shutter.stopTimer",
                defaultValue: "Stop timer",
                bundle: localization.bundle,
                locale: localization.locale
            )
            : String(
                localized: "camera.control.shutter",
                defaultValue: "Take picture",
                bundle: localization.bundle,
                locale: localization.locale
            )
    }

    var viewfinder: String {
        String(
            localized: "camera.control.viewfinder",
            defaultValue: "Viewfinder",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var focus: String {
        String(
            localized: "camera.control.focus",
            defaultValue: "Focus",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var back: String {
        String(
            localized: "camera.control.back",
            defaultValue: "Back",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    // MARK: - Hints

    /// What activating the Flash indicator does.
    var flashHint: String {
        String(
            localized: "camera.hint.flash",
            defaultValue: "Changes the flash mode.",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// What activating the indicator of a setting the user changed does.
    var changedSettingHint: String {
        String(
            localized: "camera.hint.changedSetting",
            defaultValue: "Shows the options of this setting.",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    // MARK: - Zoom

    var zoom: String {
        String(
            localized: "camera.zoom.label",
            defaultValue: "Zoom",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The current zoom of the dial, such as "2.5 times".
    func zoomValue(_ factor: CGFloat) -> String {
        let title = ZoomFactorTitle.dial(factor, locale: localization.locale)
        return String(
            localized: "camera.zoom.value",
            defaultValue: "\(title) times",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// A lens button, such as "0.5 times zoom".
    func lens(_ factor: CGFloat) -> String {
        let title = ZoomFactorTitle.dial(factor, locale: localization.locale)
        return String(
            localized: "camera.zoom.lens",
            defaultValue: "\(title) times zoom",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// A focal length under a label of the dial, such as "24MM".
    func focalLength(_ millimeters: Int) -> String {
        String(
            localized: "camera.zoom.focalLength",
            defaultValue: "\(millimeters)MM",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }
}
