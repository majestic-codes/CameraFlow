//
//  FocusLockText.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// The words of the AE/AF Lock: the stock badge, and what VoiceOver reads and announces, for what the camera locks.
struct FocusLockText {
    let localization: FlowLocalization

    init(_ localization: FlowLocalization) {
        self.localization = localization
    }

    /// The stock badge at the top of the viewfinder while the lock holds: "AE/AF LOCK", and "AE LOCK" or "AF LOCK"
    /// on a camera that locks the exposure alone or the focus alone.
    func badge(for adjustments: LockableAdjustments) -> String {
        switch adjustments {
        case .focusAndExposure:
            String(
                localized: "camera.focusLock.badge",
                defaultValue: "AE/AF LOCK",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .exposure:
            String(
                localized: "camera.focusLock.badge.exposure",
                defaultValue: "AE LOCK",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .focus:
            String(
                localized: "camera.focusLock.badge.focus",
                defaultValue: "AF LOCK",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    /// What VoiceOver announces as the lock takes or ends, naming what it holds. The words of the lock are also what
    /// it reads for the badge.
    func announcement(isLocked: Bool, of adjustments: LockableAdjustments) -> String {
        isLocked ? lockedAnnouncement(of: adjustments) : unlockedAnnouncement(of: adjustments)
    }

    /// The name of VoiceOver's action on the viewfinder, which locks without a lock and ends one, naming what the
    /// camera locks.
    func action(isLocked: Bool, of adjustments: LockableAdjustments) -> String {
        isLocked ? unlockAction(of: adjustments) : lockAction(of: adjustments)
    }

    private func lockedAnnouncement(of adjustments: LockableAdjustments) -> String {
        switch adjustments {
        case .focusAndExposure:
            String(
                localized: "camera.focusLock.locked",
                defaultValue: "Focus and exposure locked",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .exposure:
            String(
                localized: "camera.focusLock.exposure.locked",
                defaultValue: "Exposure locked",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .focus:
            String(
                localized: "camera.focusLock.focus.locked",
                defaultValue: "Focus locked",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    private func unlockedAnnouncement(of adjustments: LockableAdjustments) -> String {
        switch adjustments {
        case .focusAndExposure:
            String(
                localized: "camera.focusLock.unlocked",
                defaultValue: "Focus and exposure unlocked",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .exposure:
            String(
                localized: "camera.focusLock.exposure.unlocked",
                defaultValue: "Exposure unlocked",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .focus:
            String(
                localized: "camera.focusLock.focus.unlocked",
                defaultValue: "Focus unlocked",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    private func lockAction(of adjustments: LockableAdjustments) -> String {
        switch adjustments {
        case .focusAndExposure:
            String(
                localized: "camera.focusLock.lock",
                defaultValue: "Lock focus and exposure",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .exposure:
            String(
                localized: "camera.focusLock.exposure.lock",
                defaultValue: "Lock exposure",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .focus:
            String(
                localized: "camera.focusLock.focus.lock",
                defaultValue: "Lock focus",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    private func unlockAction(of adjustments: LockableAdjustments) -> String {
        switch adjustments {
        case .focusAndExposure:
            String(
                localized: "camera.focusLock.unlock",
                defaultValue: "Unlock focus and exposure",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .exposure:
            String(
                localized: "camera.focusLock.exposure.unlock",
                defaultValue: "Unlock exposure",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .focus:
            String(
                localized: "camera.focusLock.focus.unlock",
                defaultValue: "Unlock focus",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }
}
