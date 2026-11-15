//
//  OnboardingTextTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("Text of the introduction")
struct OnboardingTextTests {
    private static let addOnlyStep = OnboardingStep.photoLibrary(access: .addOnly, isSavingUserAdjustable: true)

    @Test("The camera page says what the camera, the library picker and the review are for")
    func cameraPage() {
        let page = OnboardingText(.system).page(for: .camera, offersPhotoLibrary: true)
        #expect(page.symbol == .camera)
        #expect(page.title == "Add Photos")
        #expect(page.rows.map(\.symbol) == [.capture, .libraryPicker, .review])
        #expect(page.rows.map(\.title) == ["Use the Camera", "Choose From Library", "Review and Mark Up"])
        let details = [
            "Take photos without leaving the app.",
            "Pick photos without giving access to your whole library.",
            "Check each photo and draw on it before you finish."
        ]
        #expect(page.rows.map(\.detail) == details)
        let footnote = "You’ll be asked for camera access next. You can change it anytime in Settings."
        #expect(page.footnote == footnote)
        #expect(page.continueTitle == "Continue")
    }

    @Test("The camera page of a flow without the photo library does not name it")
    func cameraPageWithoutLibrary() {
        let page = OnboardingText(.system).page(for: .camera, offersPhotoLibrary: false)
        #expect(page.rows.map(\.symbol) == [.capture, .review])
    }

    @Test("The library page of add-only access says the app cannot see the library, and names the switch")
    func addOnlyPage() {
        let page = OnboardingText(.system).page(for: Self.addOnlyStep, offersPhotoLibrary: true)
        #expect(page.symbol == .librarySave)
        #expect(page.title == "Save to Photos")
        #expect(page.rows.map(\.symbol) == [.copy, .addOnly, .userSwitch])
        #expect(page.rows.map(\.title) == ["Keep a Copy", "Add Only", "You’re in Control"])
        let details = [
            "Photos you take here can also be saved to your library.",
            "The app can add photos but can’t see your library.",
            "Turn saving on or off anytime in the camera."
        ]
        #expect(page.rows.map(\.detail) == details)
        let footnote = "You’ll be asked for photo library access next. You can change it anytime in Settings."
        #expect(page.footnote == footnote)
        #expect(page.continueTitle == "Continue")
    }

    @Test("The library page of an album says that it needs the library, and has no switch row when saving is fixed")
    func albumPage() {
        let step = OnboardingStep.photoLibrary(access: .readWrite, isSavingUserAdjustable: false)
        let page = OnboardingText(.system).page(for: step, offersPhotoLibrary: true)
        #expect(page.rows.map(\.symbol) == [.copy, .album])
        #expect(page.rows.map(\.title) == ["Keep a Copy", "Saved to an Album"])
        #expect(page.rows.last?.detail == "Keeping photos in an album needs access to your library.")
    }

    @Test(
        "The rows of a page have distinct symbols, which tell them apart",
        arguments: [(OnboardingStep.camera, true), (.camera, false), (addOnlyStep, true)]
    )
    func distinctRows(step: OnboardingStep, offersPhotoLibrary: Bool) {
        let page = OnboardingText(.system).page(for: step, offersPhotoLibrary: offersPhotoLibrary)
        #expect(Set(page.rows.map(\.id)).count == page.rows.count)
    }

    @Test("The introduction has stable identifiers")
    func identifiers() {
        #expect(CameraIdentifier.onboarding == "camera.onboarding")
        #expect(CameraIdentifier.onboardingTitle == "camera.onboarding.title")
        #expect(CameraIdentifier.onboardingContinue == "camera.onboarding.continue")
    }
}
