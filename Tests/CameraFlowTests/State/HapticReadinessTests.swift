//
//  HapticReadinessTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

/// The haptics readied as the gesture that may end in them begins, so they play without the delay of a Taptic
/// Engine that went idle.
@MainActor
@Suite("Haptics readied ahead of their gesture", .temporaryDirectory, .timeLimit(.minutes(1)))
struct HapticReadinessTests {

    @Test("The tiles ready the haptic of the sub-panel a tap on them opens")
    func tiles() {
        let haptics = RecordingCameraHaptics()
        let panel = ControlPanelModel(settings: [.flash, .timer], presentation: .hidden, haptics: haptics)
        #expect(haptics.prepared.isEmpty)
        panel.showTiles()
        #expect(haptics.prepared == [.settingOpened])
        #expect(haptics.events.isEmpty)
    }

    @Test("A finger on the mode switch readies the haptics its release may play, and plays none")
    func modeSwitch() {
        let harness = FlowHarness()
        let flow = harness.makeFlow()
        flow.modeSwitchTouched()
        #expect(harness.haptics.prepared == [.modeSelected, .modeRefused])
        #expect(harness.haptics.events.isEmpty)
    }

    @Test("A finger on a tile readies the haptic of the sub-panel its release opens, and opens nothing")
    func tileTouched() {
        let haptics = RecordingCameraHaptics()
        let panel = ControlPanelModel(settings: [.flash, .timer], presentation: .tiles, haptics: haptics)
        panel.tileTouched()
        #expect(haptics.prepared == [.settingOpened])
        #expect(haptics.events.isEmpty)
        #expect(panel.presentation == .tiles)
    }

    @Test("A finger on an option readies the haptic of the choice, and changes nothing")
    func optionTouched() {
        let haptics = RecordingCameraHaptics()
        let model = makeCaptureModel(service: RecordingCameraService(), haptics: haptics)
        let timer = model.settings.timer
        let flashMode = model.settings.flashMode
        model.settings.optionTouched()
        #expect(haptics.prepared == [.optionSelected])
        #expect(haptics.events.isEmpty)
        #expect(model.settings.timer == timer)
        #expect(model.settings.flashMode == flashMode)
    }

    @Test("A finger on the flip button readies the haptic of the flip, and flips nothing")
    func flipButtonTouched() async {
        let service = RecordingCameraService()
        let haptics = RecordingCameraHaptics()
        let model = makeCaptureModel(service: service, haptics: haptics)
        await model.start()
        let position = model.session.position
        let startCount = service.startCount
        model.flipButtonTouched()
        #expect(haptics.prepared == [.cameraFlipped])
        #expect(haptics.events.isEmpty)
        #expect(model.session.position == position)
        #expect(service.startCount == startCount)
    }
}
