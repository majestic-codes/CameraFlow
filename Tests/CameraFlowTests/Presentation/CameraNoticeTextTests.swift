//
//  CameraNoticeTextTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@Suite("Notice text")
struct CameraNoticeTextTests {

    @Test(
        "A camera that does not run says why in plain words",
        arguments: [
            (CameraFailure.accessDenied, "Camera access is denied in Settings"),
            (.accessRestricted, "Camera access is restricted"),
            (.unavailable(.noCamera), "Camera unavailable"),
            (.unavailable(.cannotUseCamera("The session refused the camera input")), "Camera unavailable"),
            (.stopped, "Camera unavailable")
        ]
    )
    func failure(failure: CameraFailure, message: String) {
        #expect(CameraNoticeText(.system).message(for: failure) == message)
    }

    @Test(
        "A camera that stopped says so in the flow's language, without the system's words",
        arguments: [("en", "Camera unavailable"), ("uk", "Камера недоступна"), ("de", "Kamera nicht verfügbar")]
    )
    func stoppedCamera(language: String, message: String) {
        let localization = FlowLocalization(.specific(Locale.Language(identifier: language)))
        #expect(CameraNoticeText(localization).message(for: .stopped) == message)
    }

    @Test("The button under a denied camera names Settings")
    func openSettings() {
        #expect(CameraNoticeText(.system).openSettings == "Open Settings")
        #expect(CameraIdentifier.openSettings == "camera.openSettings")
    }

    @Test(
        "The front camera's circle says what it leaves out and why it went",
        arguments: [
            (DualCameraNotice.settingOff(.livePhoto), "Live Photo off with the front camera"),
            (.settingOff(.raw), "RAW off with the front camera"),
            (.settingOff(.resolution), "12 MP off with the front camera"),
            (.settingOff(.flash), "Flash off with the front camera"),
            (.turnedOffUnderPressure, "Front camera off to cool down"),
            (.unavailable, "Front camera unavailable")
        ]
    )
    func dualCamera(notice: DualCameraNotice, message: String) {
        #expect(CameraNoticeText(.system).message(for: notice) == message)
    }
}
