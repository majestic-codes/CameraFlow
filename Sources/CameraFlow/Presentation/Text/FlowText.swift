//
//  FlowText.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// What the flow's own controls, its exit alert and its notices say.
struct FlowText {
    let localization: FlowLocalization

    init(_ localization: FlowLocalization) {
        self.localization = localization
    }

    // MARK: - Controls

    var exit: String {
        String(
            localized: "flow.control.exit",
            defaultValue: "Close",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var accept: String {
        String(
            localized: "flow.control.accept",
            defaultValue: "Done",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The value of the check mark while the set is handed over to the app.
    var handingOver: String {
        String(
            localized: "flow.control.accept.handingOver",
            defaultValue: "Preparing photos",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var photoLibrary: String {
        String(
            localized: "flow.control.library",
            defaultValue: "Photo library",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    // MARK: - Mode switch

    /// The name of a mode, as accessibility reads it.
    func modeName(_ mode: CameraFlowMode) -> String {
        switch mode {
        case .shooting: String(
            localized: "flow.mode.shooting",
            defaultValue: "Camera",
            bundle: localization.bundle,
            locale: localization.locale
        )
        case .review: String(
            localized: "flow.mode.review",
            defaultValue: "Review",
            bundle: localization.bundle,
            locale: localization.locale
        )
        }
    }

    /// The label of a mode on the switch, in the capitals of the stock mode picker.
    func modeLabel(_ mode: CameraFlowMode) -> String {
        modeName(mode).uppercased(with: localization.locale)
    }

    /// What accessibility calls the count on the review segment.
    var photosInSet: String {
        String(
            localized: "flow.mode.badge",
            defaultValue: "Photos in the set",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// What VoiceOver announces when the set grows, such as "Photos in the set: 3".
    func photosInSetAnnouncement(_ count: Int) -> String {
        let number = count.formatted(.number.locale(localization.locale))
        return String(
            localized: "flow.mode.badge.announcement",
            defaultValue: "Photos in the set: \(number)",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var loadingPhotos: String {
        String(
            localized: "flow.mode.importing",
            defaultValue: "Loading photos",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    // MARK: - Exit alert

    var exitTitle: String {
        String(
            localized: "flow.exit.title",
            defaultValue: "Leave without the photos?",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// How many photos leaving loses, and that the ones taken with the camera are gone for good.
    func exitMessage(for confirmation: ExitConfirmation) -> String {
        let count = confirmation.photoCount
        return if confirmation.hasCameraPhotos {
            String(
                localized: "flow.exit.message.camera",
                defaultValue: "The set has \(count) photos. The ones taken with the camera will be gone for good.",
                bundle: localization.bundle,
                locale: localization.locale
            )
        } else {
            String(
                localized: "flow.exit.message.library",
                defaultValue: "The set has \(count) photos.",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    var exitStay: String {
        String(
            localized: "flow.exit.stay",
            defaultValue: "Stay",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var exitLeave: String {
        String(
            localized: "flow.exit.leave",
            defaultValue: "Leave",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    // MARK: - Notices

    /// The short line at the top of the viewfinder frame, nil when there is nothing to say: what
    /// `CameraFlowModel.notice` picks.
    @MainActor
    func notice<Canvas: MarkupCanvas>(for flow: CameraFlowModel<Canvas>) -> String? {
        flow.notice.map(message)
    }

    func message(for notice: FlowNotice) -> String {
        switch notice {
        case let .camera(notice): CameraNoticeText(localization).message(for: notice)
        case let .photoSet(notice): message(for: notice)
        case let .markup(notice): MarkupText(localization).message(for: notice)
        }
    }

    /// Why a photo was not saved to the photo library, or saving could not be switched on.
    func message(for failure: CameraFlowPhotoLibrarySaveFailure) -> String {
        switch failure {
        case .accessDenied:
            String(
                localized: "flow.notice.save.accessDenied",
                defaultValue: "Photo library access is denied in Settings",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .accessRestricted:
            String(
                localized: "flow.notice.save.accessRestricted",
                defaultValue: "Photo library access is restricted",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .limitedAccess:
            String(
                localized: "flow.notice.save.limitedAccess",
                defaultValue: "The album needs full photo library access",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .libraryError(.notEnoughSpace):
            CameraNoticeText(localization).message(for: .notEnoughStorage)
        case .libraryError:
            String(
                localized: "flow.notice.save.failed",
                defaultValue: "The photo could not be saved to the library",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    func message(for notice: PhotoSetNotice) -> String {
        switch notice {
        case let .importFailed(count):
            String(
                localized: "flow.notice.importFailed",
                defaultValue: "\(count) photos could not be loaded",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case let .limitReached(maximum):
            CameraNoticeText(localization).message(for: .captureLimitReached(maximum))
        case let .librarySaveFailed(failure):
            message(for: failure)
        case .notEnoughStorage:
            CameraNoticeText(localization).message(for: .notEnoughStorage)
        case .copyFailed:
            String(
                localized: "flow.notice.copyFailed",
                defaultValue: "The copy with the drawing could not be saved",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }
}
