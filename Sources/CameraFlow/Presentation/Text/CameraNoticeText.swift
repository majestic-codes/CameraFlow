//
//  CameraNoticeText.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// What the screen says about a camera that is paused, failed or could not take a photo.
struct CameraNoticeText {
    let localization: FlowLocalization

    init(_ localization: FlowLocalization) {
        self.localization = localization
    }

    /// The short line of what the camera says: an interruption, a failed capture, a photo taken without a part of
    /// it, the front camera's circle or the refused saving to the photo library.
    func message(for notice: CameraNotice) -> String {
        switch notice {
        case let .interrupted(interruption): message(for: interruption)
        case let .captureFailed(error): message(for: error)
        case let .captureLoss(loss): message(for: loss)
        case let .dualCamera(notice): message(for: notice)
        case let .librarySavingRefused(failure): FlowText(localization).message(for: failure)
        }
    }

    /// What a photo was taken without, when a part of its capture failed.
    func message(for loss: CapturedPhotoLoss) -> String {
        switch loss {
        case .livePhotoMovie:
            String(
                localized: "camera.notice.withoutLivePhoto",
                defaultValue: "Photo taken without Live Photo",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .circleCameraFrame:
            String(
                localized: "camera.notice.withoutDualCapture",
                defaultValue: "Photo taken without Dual Capture",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    func message(for notice: DualCameraNotice) -> String {
        switch notice {
        case let .settingOff(setting):
            message(forSettingOff: setting)
        case .turnedOffUnderPressure:
            String(
                localized: "camera.notice.dualCamera.pressure",
                defaultValue: "Front camera off to cool down",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .unavailable:
            String(
                localized: "camera.notice.dualCamera.unavailable",
                defaultValue: "Front camera unavailable",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    private func message(forSettingOff setting: DualCameraSetting) -> String {
        switch setting {
        case .livePhoto:
            String(
                localized: "camera.notice.dualCamera.livePhoto",
                defaultValue: "Live Photo off with the front camera",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .raw:
            String(
                localized: "camera.notice.dualCamera.raw",
                defaultValue: "RAW off with the front camera",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .resolution:
            String(
                localized: "camera.notice.dualCamera.resolution",
                defaultValue: "\(PhotoCaptureResolution.preferredMegapixels) MP off with the front camera",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .flash:
            String(
                localized: "camera.notice.dualCamera.flash",
                defaultValue: "Flash off with the front camera",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    /// The message in the viewfinder of a camera that does not run.
    func message(for failure: CameraFailure) -> String {
        switch failure {
        case .accessDenied:
            String(
                localized: "camera.notice.accessDenied",
                defaultValue: "Camera access is denied in Settings",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .accessRestricted:
            String(
                localized: "camera.notice.accessRestricted",
                defaultValue: "Camera access is restricted",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case let .unavailable(error):
            message(for: error)
        case .stopped:
            cameraUnavailable
        }
    }

    /// The button under the message of a camera that may run when started again.
    var retry: String {
        String(
            localized: "camera.notice.retry",
            defaultValue: "Try Again",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The button under the message of a camera the user denied, which opens the app's page of Settings.
    var openSettings: String {
        String(
            localized: "camera.notice.openSettings",
            defaultValue: "Open Settings",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    func message(for interruption: CameraInterruption) -> String {
        switch interruption {
        case .cameraInUseByAnotherClient:
            String(
                localized: "camera.notice.cameraInUse",
                defaultValue: "Camera in use by another app",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .audioInUseByAnotherClient:
            String(
                localized: "camera.notice.audioInUse",
                defaultValue: "Audio in use by another app",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .cameraUnavailableBesideOtherApps:
            String(
                localized: "camera.notice.besideOtherApps",
                defaultValue: "Camera unavailable with other apps open",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .cameraUnavailableUnderPressure:
            String(
                localized: "camera.notice.coolingDown",
                defaultValue: "Camera paused to cool down",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .cameraUnavailableInBackground, .sensitiveContentMitigationActivated, .other:
            String(
                localized: "camera.notice.paused",
                defaultValue: "Camera paused",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    func message(for error: CameraServiceError) -> String {
        switch error {
        case let .interrupted(interruption):
            message(for: interruption)
        case let .unsupported(option):
            message(for: option)
        case .dualCameraUnavailable:
            message(for: DualCameraNotice.unavailable)
        case .noCamera, .cannotUseCamera, .notRunning:
            cameraUnavailable
        case .captureFailed, .noImageData, .cannotCrop, .cannotStore:
            String(
                localized: "camera.notice.photoFailed",
                defaultValue: "Photo could not be taken",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .notEnoughStorage:
            String(
                localized: "camera.notice.notEnoughStorage",
                defaultValue: "Not enough storage",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case let .captureLimitReached(count):
            String(
                localized: "camera.notice.limitReached",
                defaultValue: "Limit of \(count) photos reached",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    /// A camera that cannot start or that stopped, whatever the system said about it.
    private var cameraUnavailable: String {
        String(
            localized: "camera.notice.unavailable",
            defaultValue: "Camera unavailable",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    private func message(for option: PhotoCaptureOption) -> String {
        switch option {
        case .flash:
            String(
                localized: "camera.notice.flashUnavailable",
                defaultValue: "Flash unavailable",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .livePhoto:
            String(
                localized: "camera.notice.livePhotoUnavailable",
                defaultValue: "Live Photo unavailable",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .format:
            String(
                localized: "camera.notice.formatUnavailable",
                defaultValue: "Format unavailable",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .resolution:
            String(
                localized: "camera.notice.resolutionUnavailable",
                defaultValue: "Resolution unavailable",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .livePhotoWithRAW:
            String(
                localized: "camera.notice.livePhotoWithRAW",
                defaultValue: "Live Photo unavailable with RAW",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }
}
