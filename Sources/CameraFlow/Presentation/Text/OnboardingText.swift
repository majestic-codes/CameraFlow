//
//  OnboardingText.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// What the introduction says before the camera, the location and the photo library are asked for.
struct OnboardingText {
    let localization: FlowLocalization

    init(_ localization: FlowLocalization) {
        self.localization = localization
    }

    /// The page of a step. The camera's page names the photo library only in a flow that offers it.
    func page(for step: OnboardingStep, offersPhotoLibrary: Bool) -> OnboardingPage {
        switch step {
        case .camera:
            OnboardingPage(
                symbol: .camera,
                title: cameraTitle,
                rows: cameraRows(offersPhotoLibrary: offersPhotoLibrary),
                footnote: cameraFootnote,
                continueTitle: continueTitle
            )
        case .location:
            OnboardingPage(
                symbol: .location,
                title: locationTitle,
                rows: locationRows,
                footnote: locationFootnote,
                continueTitle: continueTitle
            )
        case let .photoLibrary(access, isSavingUserAdjustable):
            OnboardingPage(
                symbol: .librarySave,
                title: libraryTitle,
                rows: libraryRows(access: access, isSavingUserAdjustable: isSavingUserAdjustable),
                footnote: libraryFootnote,
                continueTitle: continueTitle
            )
        }
    }

    // MARK: - Button

    var continueTitle: String {
        String(
            localized: "onboarding.continue",
            defaultValue: "Continue",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    // MARK: - Camera

    private var cameraTitle: String {
        String(
            localized: "onboarding.camera.title",
            defaultValue: "Add Photos",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    private var cameraFootnote: String {
        String(
            localized: "onboarding.camera.footnote",
            defaultValue: "You’ll be asked for camera access next. You can change it anytime in Settings.",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    private func cameraRows(offersPhotoLibrary: Bool) -> [OnboardingPage.Row] {
        let captureTitle = String(
            localized: "onboarding.camera.capture.title",
            defaultValue: "Use the Camera",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let captureDetail = String(
            localized: "onboarding.camera.capture.detail",
            defaultValue: "Take photos without leaving the app.",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let capture = OnboardingPage.Row(symbol: .capture, title: captureTitle, detail: captureDetail)
        let pickerTitle = String(
            localized: "onboarding.camera.picker.title",
            defaultValue: "Choose From Library",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let pickerDetail = String(
            localized: "onboarding.camera.picker.detail",
            defaultValue: "Pick photos without giving access to your whole library.",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let picker = OnboardingPage.Row(symbol: .libraryPicker, title: pickerTitle, detail: pickerDetail)
        let reviewTitle = String(
            localized: "onboarding.camera.review.title",
            defaultValue: "Review and Mark Up",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let reviewDetail = String(
            localized: "onboarding.camera.review.detail",
            defaultValue: "Check each photo and draw on it before you finish.",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let review = OnboardingPage.Row(symbol: .review, title: reviewTitle, detail: reviewDetail)
        return offersPhotoLibrary ? [capture, picker, review] : [capture, review]
    }

    // MARK: - Location

    private var locationTitle: String {
        String(
            localized: "onboarding.location.title",
            defaultValue: "Photo Locations",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    private var locationFootnote: String {
        String(
            localized: "onboarding.location.footnote",
            defaultValue: "You’ll be asked for location access next. You can change it anytime in Settings.",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    private var locationRows: [OnboardingPage.Row] {
        let placeTitle = String(
            localized: "onboarding.location.place.title",
            defaultValue: "Where It Was Taken",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let placeDetail = String(
            localized: "onboarding.location.place.detail",
            defaultValue: "Each photo you take records the place where it was taken.",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let place = OnboardingPage.Row(symbol: .place, title: placeTitle, detail: placeDetail)
        let inUseTitle = String(
            localized: "onboarding.location.inUse.title",
            defaultValue: "Only While in Use",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let inUseDetail = String(
            localized: "onboarding.location.inUse.detail",
            defaultValue: "Your location is used only while you’re using the app.",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let inUse = OnboardingPage.Row(symbol: .inUse, title: inUseTitle, detail: inUseDetail)
        let choiceTitle = String(
            localized: "onboarding.location.optional.title",
            defaultValue: "Your Choice",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let choiceDetail = String(
            localized: "onboarding.location.optional.detail",
            defaultValue: "Without location access, photos are taken just the same.",
            bundle: localization.bundle,
            locale: localization.locale
        )
        let choice = OnboardingPage.Row(symbol: .choice, title: choiceTitle, detail: choiceDetail)
        return [place, inUse, choice]
    }
}
