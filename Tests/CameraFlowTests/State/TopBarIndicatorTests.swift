//
//  TopBarIndicatorTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Top bar indicators of the changed settings", .temporaryDirectory, .timeLimit(.minutes(1)))
struct TopBarIndicatorTests {

    private func makeModel(initialState: CameraFlowInitialState = CameraFlowInitialState()) -> PhotoCameraModel {
        makeCaptureModel(service: RecordingCameraService(), initialState: initialState)
    }

    @Test("With every setting at its default the top bar holds the controls alone")
    func defaults() {
        let settings = makeModel().settings
        #expect(settings.changedSettings.isEmpty)
        #expect(settings.topBarItems == [.flash, .live])
    }

    @Test("A setting moved off its default gets an indicator after the controls, in the order of the tiles")
    func changedSettings() async {
        let model = makeModel()
        await model.start()
        let settings = model.settings
        settings.select(timer: .threeSeconds)
        #expect(settings.topBarItems == [.flash, .live, .timer])
        settings.select(aspectRatio: .sixteenByNine)
        #expect(settings.topBarItems == [.flash, .live, .aspect, .timer])
        settings.select(photoFormat: .raw)
        settings.setExposureBias(0.7)
        #expect(settings.topBarItems == [.flash, .live, .aspect, .timer, .exposure, .format])
    }

    @Test("An indicator goes as soon as its setting is back at the default")
    func backToDefault() async {
        let model = makeModel()
        await model.start()
        let settings = model.settings
        settings.select(aspectRatio: .square)
        settings.setExposureBias(-1)
        #expect(settings.changedSettings == [.aspect, .exposure])
        settings.select(aspectRatio: .fourByThree)
        settings.setExposureBias(0)
        #expect(settings.changedSettings.isEmpty)
    }

    @Test("A value the app opened with counts as changed when it is not the stock default")
    func initialValues() {
        var state = CameraFlowInitialState()
        state.aspectRatio.value = .sixteenByNine
        state.timer.value = .tenSeconds
        #expect(makeModel(initialState: state).settings.changedSettings == [.aspect, .timer])
    }

    @Test("A setting the app fixed off its default has no indicator")
    func fixedSettings() {
        var state = CameraFlowInitialState()
        state.aspectRatio = .fixed(.square)
        state.timer = .fixed(.fiveSeconds)
        state.exposureBias = .fixed(1)
        state.photoFormat = .fixed(.raw)
        let settings = makeModel(initialState: state).settings
        #expect(settings.changedSettings.isEmpty)
        #expect(settings.topBarItems == [.flash, .live])
    }

    @Test("RAW shows while it is in effect: not on a camera without it, and not before the camera has started")
    func rawInEffect() async {
        var state = CameraFlowInitialState()
        state.photoFormat.value = .raw
        let model = makeModel(initialState: state)
        let settings = model.settings
        #expect(settings.changedSettings.isEmpty)
        await model.start()
        #expect(settings.changedSettings == [.format])
        await model.flipCamera()
        #expect(settings.effectivePhotoFormat == .heif)
        #expect(settings.changedSettings.isEmpty)
    }

    @Test("The indicators of the changed settings name their sub-panels, which the panel can open")
    func indicatorsOpenSubPanels() async {
        let model = makeModel()
        await model.start()
        model.settings.select(timer: .threeSeconds)
        for setting in model.settings.changedSettings {
            #expect(model.panel.settings.contains(setting))
            model.panel.showSubPanel(setting)
            #expect(model.panel.presentation == .subPanel(setting))
        }
    }
}
