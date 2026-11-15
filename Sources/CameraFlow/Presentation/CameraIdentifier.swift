//
//  CameraIdentifier.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// Stable accessibility identifiers of the camera screen.
enum CameraIdentifier {
    static let viewfinder = "camera.viewfinder"
    static let flash = "camera.topBar.flash"
    static let livePhoto = "camera.topBar.live"
    static let dualCamera = "camera.topBar.dualCamera"
    static let dualCameraCircle = "camera.dualCameraCircle"
    static let librarySave = "camera.topBar.save"
    static let lensRow = "camera.lensRow"
    static let zoomDial = "camera.zoomDial"
    static let shutter = "camera.shutter"
    static let more = "camera.more"
    static let flip = "camera.flip"
    static let focusReticle = "camera.focusReticle"
    static let focusReticleExposure = "camera.focusReticle.exposure"
    /// The AE/AF LOCK badge at the top of the viewfinder.
    static let focusLock = "camera.focusLock"
    static let countdown = "camera.countdown"
    static let notice = "camera.notice"
    static let retryCamera = "camera.retry"
    static let openSettings = "camera.openSettings"
    static let panel = "camera.panel"
    /// The grabber of the control panel as a button that closes the panel.
    static let panelDismiss = "camera.panel.dismiss"
    static let subPanel = "camera.subpanel"
    static let subPanelBack = "camera.subpanel.back"
    static let subPanelTitle = "camera.subpanel.title"
    static let subPanelValue = "camera.subpanel.value"
    /// The approximate size of one photo, under the options of the Format sub-panel.
    static let subPanelPhotoSize = "camera.subpanel.photoSize"
    /// The way to the app's page of Settings under the options of the Save sub-panel, while the library is refused.
    static let subPanelLibrarySettings = "camera.subpanel.librarySettings"
    /// The introduction shown before the camera is asked for, its title and its Continue button.
    static let onboarding = "camera.onboarding"
    static let onboardingTitle = "camera.onboarding.title"
    static let onboardingContinue = "camera.onboarding.continue"

    static func panelTile(_ setting: CameraSetting) -> String {
        "camera.panel.tile." + setting.rawValue
    }

    /// The top bar indicator of a changed setting, such as "camera.topBar.aspect".
    static func topBarIndicator(_ setting: CameraSetting) -> String {
        "camera.topBar." + setting.rawValue
    }

    /// The name is the option as the sub-panel writes it, lowercased, such as "auto", "16:9" and "24mp".
    static func subPanelOption(_ name: String) -> String {
        "camera.subpanel.option." + name
    }

    /// The factor is written with a point and no trailing zero in every locale, such as "camera.lens.0.5".
    static func lens(_ factor: CGFloat) -> String {
        let locale = Locale(identifier: "en_US_POSIX")
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2)).locale(locale)
        return "camera.lens." + Double(factor).formatted(style)
    }
}
