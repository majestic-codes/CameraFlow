//
//  CameraSettingTextTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("Setting and control text")
struct CameraSettingTextTests {

    @Test(
        "A setting has a name, and the same name in capitals for its sub-panel and its tile",
        arguments: [
            (CameraSetting.flash, "Flash", "FLASH"),
            (.live, "Live", "LIVE"),
            (.aspect, "Aspect", "ASPECT"),
            (.timer, "Timer", "TIMER"),
            (.exposure, "Exposure", "EXPOSURE"),
            (.format, "Format", "FORMAT"),
            (.librarySave, "Save", "SAVE")
        ]
    )
    func names(setting: CameraSetting, name: String, title: String) {
        #expect(CameraSettingText(.system).name(of: setting) == name)
        #expect(CameraSettingText(.system).title(of: setting) == title)
        #expect(CameraSettingText(.system).tileName(of: setting) == name)
        #expect(CameraSettingText(.system).tileLabel(of: setting) == title)
    }

    @Test("The second camera's circle has its full name on its sub-panel and the short one under its tile")
    func dualCameraNames() {
        #expect(CameraSettingText(.system).name(of: .dualCamera) == "Dual Capture")
        #expect(CameraSettingText(.system).name(of: .dualCamera) == CameraControlText(.system).dualCamera)
        #expect(CameraSettingText(.system).title(of: .dualCamera) == "DUAL CAPTURE")
        #expect(CameraSettingText(.system).tileName(of: .dualCamera) == "Dual")
        #expect(CameraSettingText(.system).tileLabel(of: .dualCamera) == "DUAL")
    }

    @Test(
        "A flash mode is written short in its sub-panel",
        arguments: [(CameraFlowFlashMode.auto, "Auto"), (.alwaysOn, "On"), (.off, "Off")]
    )
    func flashModes(mode: CameraFlowFlashMode, option: String) {
        #expect(CameraSettingText(.system).flashMode(mode) == option)
    }

    @Test(
        "A timer delay is written short in the sub-panel",
        arguments: [(CameraFlowTimer.off, "Off"), (.threeSeconds, "3s"), (.tenSeconds, "10s")]
    )
    func timers(timer: CameraFlowTimer, value: String) {
        #expect(CameraSettingText(.system).timer(timer) == value)
    }

    @Test(
        "A megapixel count is written in the digits of the locale",
        arguments: [("en-US", "12"), ("uk-UA", "12"), ("ar-EG", "١٢"), ("fa-IR", "۱۲")]
    )
    func megapixelDigits(locale: String, digits: String) {
        let localization = FlowLocalization(.specific(Locale.Language(identifier: locale)))
        #expect(CameraSettingText(localization).megapixelCount(12) == digits)
    }

    @Test("The shutter says what a tap does")
    func shutter() {
        #expect(CameraControlText(.system).shutter(isCountingDown: false) == "Take picture")
        #expect(CameraControlText(.system).shutter(isCountingDown: true) == "Stop timer")
    }

    @Test("Zoom reads as a factor")
    func zoom() {
        #expect(CameraControlText(.system).zoomValue(2) == "2 times")
        #expect(CameraControlText(.system).lens(8) == "8 times zoom")
    }

    @Test("The limit notice names the limit")
    func limitNotice() {
        #expect(CameraNoticeText(.system).message(for: .captureLimitReached(5)) == "Limit of 5 photos reached")
    }

    @Test("Exposure reads as a signed number of stops")
    func signedStops() {
        #expect(CameraSettingText(.system).signedStops(1.25).first == "+")
        #expect(CameraSettingText(.system).signedStops(-0.7).first == "-")
        #expect(CameraSettingText(.system).signedStops(0).first == "0")
        let text = CameraSettingText(.system)
        #expect(text.signedStops(0.7) == "+" + text.signedStops(-0.7).dropFirst())
    }
}
