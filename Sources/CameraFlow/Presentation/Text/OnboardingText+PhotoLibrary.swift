//
//  OnboardingText+PhotoLibrary.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// The page of the introduction that asks for the photo library.
extension OnboardingText {
    var libraryTitle: String {
        String(
            localized: "onboarding.library.title",
            defaultValue: "Save to Photos",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    var libraryFootnote: String {
        String(
            localized: "onboarding.library.footnote",
            defaultValue: "You’ll be asked for photo library access next. You can change it anytime in Settings.",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    func libraryRows(access: PhotoLibraryAccess, isSavingUserAdjustable: Bool) -> [OnboardingPage.Row] {
        let copyTitle = String(
            localized: "onboarding.library.copy.title",
            defaultValue: "Keep a Copy",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let copyDetail = String(
            localized: "onboarding.library.copy.detail",
            defaultValue: "Photos you take here can also be saved to your library.",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let copy = OnboardingPage.Row(symbol: .copy, title: copyTitle, detail: copyDetail)
        let userSwitchTitle = String(
            localized: "onboarding.library.switch.title",
            defaultValue: "You’re in Control",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let userSwitchDetail = String(
            localized: "onboarding.library.switch.detail",
            defaultValue: "Turn saving on or off anytime in the camera.",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let userSwitch = OnboardingPage.Row(symbol: .userSwitch, title: userSwitchTitle, detail: userSwitchDetail)
        let rows = [copy, accessRow(for: access)]
        return isSavingUserAdjustable ? rows + [userSwitch] : rows
    }

    /// What the access lets the app do: add-only access cannot read the library, an album needs all of it.
    private func accessRow(for access: PhotoLibraryAccess) -> OnboardingPage.Row {
        switch access {
        case .addOnly: OnboardingPage.Row(symbol: .addOnly, title: addOnlyTitle, detail: addOnlyDetail)
        case .readWrite: OnboardingPage.Row(symbol: .album, title: albumTitle, detail: albumDetail)
        }
    }

    private var addOnlyTitle: String {
        String(
            localized: "onboarding.library.addOnly.title",
            defaultValue: "Add Only",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    private var addOnlyDetail: String {
        String(
            localized: "onboarding.library.addOnly.detail",
            defaultValue: "The app can add photos but can’t see your library.",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    private var albumTitle: String {
        String(
            localized: "onboarding.library.album.title",
            defaultValue: "Saved to an Album",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    private var albumDetail: String {
        String(
            localized: "onboarding.library.album.detail",
            defaultValue: "Keeping photos in an album needs access to your library.",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }
}
