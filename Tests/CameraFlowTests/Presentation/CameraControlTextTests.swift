//
//  CameraControlTextTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("What accessibility reads for the controls, and what a paused or failed camera says")
struct CameraControlTextTests {

    @Test("Every control of the camera screen has a name")
    func controls() {
        #expect(CameraControlText(.system).cameraControls == "Camera controls")
        #expect(CameraControlText(.system).cameraChooser == "Camera chooser")
        #expect(CameraControlText(.system).livePhoto == "Live Photo")
        #expect(CameraControlText(.system).dualCamera == "Dual Capture")
        #expect(CameraControlText(.system).viewfinder == "Viewfinder")
        #expect(CameraControlText(.system).focus == "Focus")
        #expect(CameraControlText(.system).back == "Back")
        #expect(CameraControlText(.system).zoom == "Zoom")
    }

    @Test(
        "The circle is named after the camera it shows",
        arguments: [(CameraPosition.front, "Front camera"), (.back, "Back camera")]
    )
    func dualCameraCircle(position: CameraPosition, name: String) {
        #expect(CameraControlText(.system).dualCameraCircle(showing: position) == name)
    }

    @Test("Focal lengths under the labels of the dial are written in capitals, in the script of the language")
    func focalLength() {
        let english = FlowLocalization(.specific(Locale.Language(identifier: "en")))
        let ukrainian = FlowLocalization(.specific(Locale.Language(identifier: "uk")))
        #expect(CameraControlText(english).focalLength(24) == "24MM")
        #expect(CameraControlText(ukrainian).focalLength(24) == "24ММ")
    }

    @Test("The controls of the flow have a name")
    func flowControls() {
        #expect(FlowText(.system).exit == "Close")
        #expect(FlowText(.system).accept == "Done")
        #expect(FlowText(.system).photoLibrary == "Photo library")
        #expect(FlowText(.system).photosInSet == "Photos in the set")
        #expect(FlowText(.system).loadingPhotos == "Loading photos")
    }

    @Test("The check mark says that the set is being handed over, and a growing set is announced with its count")
    func flowAnnouncements() {
        #expect(FlowText(.system).handingOver == "Preparing photos")
        #expect(FlowText(.system).photosInSetAnnouncement(3) == "Photos in the set: 3")
        let arabic = FlowText(FlowLocalization(.specific(Locale.Language(identifier: "ar-EG"))))
        #expect(arabic.photosInSetAnnouncement(12).contains("١٢"))
    }

    @Test("The grabber of the control panel closes it, and the indicators say what activating them does")
    func panelDismissalAndHints() {
        #expect(CameraControlText(.system).dismissControls == "Dismiss camera controls")
        #expect(CameraControlText(.system).flashHint == "Changes the flash mode.")
        #expect(CameraControlText(.system).changedSettingHint == "Shows the options of this setting.")
        #expect(CameraIdentifier.panelDismiss == "camera.panel.dismiss")
    }

    @Test(
        "The settings the flow adds to the stock ones have a name and a tile title",
        arguments: [(CameraSetting.dualCamera, "Dual Capture", "DUAL CAPTURE"), (.librarySave, "Save", "SAVE")]
    )
    func flowSettings(setting: CameraSetting, name: String, title: String) {
        #expect(CameraSettingText(.system).name(of: setting) == name)
        #expect(CameraSettingText(.system).title(of: setting) == title)
    }

    @Test("The Save sub-panel says where the photos go: the library, or the album by its name")
    func librarySaveDestination() {
        #expect(CameraSettingText(.system).librarySaveDestination(.library) == "Photo library")
        let destination = CameraSettingText(.system).librarySaveDestination(.album(named: "Inspections"))
        #expect(destination == "Album “Inspections”")
    }

    @Test("The tiles, the indicators and the options of the panel are found by the raw value of their setting")
    func panelIdentifiers() {
        #expect(CameraIdentifier.panelTile(.flash) == "camera.panel.tile.flash")
        #expect(CameraIdentifier.panelTile(.librarySave) == "camera.panel.tile." + CameraSetting.librarySave.rawValue)
        #expect(CameraIdentifier.topBarIndicator(.aspect) == "camera.topBar.aspect")
        #expect(CameraIdentifier.topBarIndicator(.format) == "camera.topBar.format")
        #expect(CameraIdentifier.subPanelOption("16:9") == "camera.subpanel.option.16:9")
    }

    // MARK: - Notices

    @Test("The button under a camera that may run again offers another try")
    func retry() {
        #expect(CameraNoticeText(.system).retry == "Try Again")
        #expect(CameraIdentifier.retryCamera == "camera.retry")
    }

    @Test(
        "An interrupted camera says what took it away",
        arguments: [
            (CameraInterruption.cameraInUseByAnotherClient, "Camera in use by another app"),
            (.audioInUseByAnotherClient, "Audio in use by another app"),
            (.cameraUnavailableBesideOtherApps, "Camera unavailable with other apps open"),
            (.cameraUnavailableUnderPressure, "Camera paused to cool down"),
            (.cameraUnavailableInBackground, "Camera paused"),
            (.sensitiveContentMitigationActivated, "Camera paused"),
            (.other(7), "Camera paused")
        ]
    )
    func interruption(interruption: CameraInterruption, message: String) {
        #expect(CameraNoticeText(.system).message(for: interruption) == message)
        #expect(CameraNoticeText(.system).message(for: CameraServiceError.interrupted(interruption)) == message)
    }

    @Test(
        "A photo the camera cannot take as asked names the setting it lacks",
        arguments: [
            (PhotoCaptureOption.flash(.alwaysOn), "Flash unavailable"),
            (.livePhoto, "Live Photo unavailable"),
            (.format(.raw), "Format unavailable"),
            (.resolution, "Resolution unavailable"),
            (.livePhotoWithRAW, "Live Photo unavailable with RAW")
        ]
    )
    func unsupportedOption(option: PhotoCaptureOption, message: String) {
        #expect(CameraNoticeText(.system).message(for: CameraServiceError.unsupported(option)) == message)
    }

    @Test(
        "A failed capture says in plain words whether the camera or the photo is at fault",
        arguments: [
            (CameraServiceError.dualCameraUnavailable("The pair cannot start"), "Front camera unavailable"),
            (.noCamera, "Camera unavailable"),
            (.cannotUseCamera("The input was refused"), "Camera unavailable"),
            (.notRunning, "Camera unavailable"),
            (.captureFailed("The sensor gave nothing"), "Photo could not be taken"),
            (.noImageData, "Photo could not be taken"),
            (.cannotCrop("The photo cannot be decoded"), "Photo could not be taken"),
            (.cannotStore("The disk is full"), "Photo could not be taken")
        ]
    )
    func serviceError(error: CameraServiceError, message: String) {
        #expect(CameraNoticeText(.system).message(for: error) == message)
    }

    @Test(
        "A photo taken without a part that failed says which part it lacks",
        arguments: [
            (CapturedPhotoLoss.livePhotoMovie, "Photo taken without Live Photo", "Знімок зроблено без Live Photo"),
            (.circleCameraFrame, "Photo taken without Dual Capture", "Знімок зроблено без подвійного захоплення")
        ]
    )
    func captureLoss(loss: CapturedPhotoLoss, english: String, ukrainian: String) {
        #expect(CameraNoticeText(.system).message(for: loss) == english)
        let ukrainianText = CameraNoticeText(FlowLocalization(.specific(Locale.Language(identifier: "uk"))))
        #expect(ukrainianText.message(for: loss) == ukrainian)
    }

    @Test(
        "A photo that did not reach the library says why",
        arguments: [
            (CameraFlowPhotoLibrarySaveFailure.accessDenied, "Photo library access is denied in Settings"),
            (.accessRestricted, "Photo library access is restricted"),
            (.limitedAccess, "The album needs full photo library access"),
            (.libraryError(.noAssetCreated), "The photo could not be saved to the library")
        ]
    )
    func saveFailure(failure: CameraFlowPhotoLibrarySaveFailure, message: String) {
        #expect(FlowText(.system).message(for: failure) == message)
    }
}
