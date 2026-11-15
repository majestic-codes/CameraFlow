//
//  PhotoCameraModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Photo camera model", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoCameraModelTests {
    let service = RecordingCameraService()
    let haptics = RecordingCameraHaptics()
    let clock = ManualClock()

    func makeModel(
        initialState: CameraFlowInitialState = CameraFlowInitialState(),
        onCapture: @escaping (CameraCapture) -> Void = { _ in }
    ) -> PhotoCameraModel {
        PhotoCameraModel(
            service: service,
            haptics: haptics,
            attitudeSensor: ManualAttitudeSensor(),
            initialState: Self.withLivePhoto(initialState),
            clock: clock,
            files: CaptureTestSupport.makeFileStore(),
            onCapture: onCapture
        )
    }

    /// The state with Live Photo adjustable, as the tests of the whole model expect it.
    private static func withLivePhoto(_ initialState: CameraFlowInitialState) -> CameraFlowInitialState {
        var state = initialState
        state.isLivePhotoEnabled.isUserAdjustable = true
        return state
    }

    @Test("Starting brings up the back camera on its main lens")
    func start() async {
        let model = makeModel()
        await model.start()
        #expect(service.calls == [.start(.back), .exposureBias(0)])
        #expect(model.zoom.lenses.map(\.factor) == [0.5, 1, 2, 4, 8])
        #expect(model.zoom.factor == 1)
        #expect(model.zoom.activeLensIndex == 1)
        #expect(model.zoom.dialLabelFactors == [0.5, 1, 2, 4, 8, 40])
        #expect(model.zoom.dialSnapFactors == [1, 2, 4, 8])
        #expect(model.session.failure == nil)
    }

    @Test("A stopped camera resumes on the same side and at the same zoom")
    func resume() async {
        let model = makeModel()
        await model.start()
        await model.flipCamera()
        model.zoom.setZoom(3)
        model.stop()
        let callsBefore = service.calls.count
        await model.resume()
        #expect(Array(service.calls.dropFirst(callsBefore)) == [.start(.front), .exposureBias(0), .setZoom(3)])
        #expect(model.session.position == .front)
        #expect(model.zoom.factor == 3)
    }

    @Test("A camera that never ran is not started by resuming")
    func resumeBeforeStart() async {
        service.authorization = .denied
        let model = makeModel()
        await model.start()
        await model.resume()
        #expect(service.calls.isEmpty)
        #expect(model.session.failure == .accessDenied)
    }

    @Test("A camera that cannot start again keeps its zoom for the next try")
    func resumeFailure() async {
        let model = makeModel()
        await model.start()
        model.zoom.setZoom(2)
        model.stop()
        service.startError = .noCamera
        await model.resume()
        #expect(model.session.failure == .unavailable(.noCamera))
        #expect(model.zoom.factor == 2)
        #expect(service.calls.last == .start(.back))
    }

    @Test("The initial state sets zoom, dial, settings and panel")
    func initialState() async {
        var state = CameraFlowInitialState()
        state.zoomFactor = 3
        state.isZoomDialOpen = true
        state.flashMode.value = .off
        state.isLivePhotoEnabled.value = true
        state.aspectRatio.value = .square
        state.timer.value = .fiveSeconds
        state.exposureBias.value = 5
        state.photoFormat.value = .raw
        state.panel = .subPanel(.timer)
        let model = makeModel(initialState: state)
        await model.start()
        await CameraFixtureScript(initialState: state, clock: clock).play(on: model)
        #expect(model.zoom.factor == 3)
        #expect(model.zoom.activeLensIndex == 2)
        #expect(model.zoom.isDialOpen)
        #expect(model.settings.flashMode == .off)
        #expect(model.settings.isLivePhotoEnabled)
        #expect(model.settings.aspectRatio == .square)
        #expect(model.settings.timer == .fiveSeconds)
        #expect(model.settings.exposureBias == 2)
        #expect(model.settings.photoFormat == .raw)
        #expect(model.panel.presentation == .subPanel(.timer))
        #expect(service.calls == [.start(.back), .exposureBias(2), .setZoom(3)])
    }

    @Test("A camera that cannot start is reported")
    func unavailable() async {
        service.startError = .noCamera
        let model = makeModel()
        await model.start()
        #expect(model.session.failure == .unavailable(.noCamera))
        #expect(model.zoom.lenses.isEmpty)
    }

    @Test("A lens tap ramps the zoom, the dial sets it at once and clamps it")
    func zoom() async {
        let model = makeModel()
        await model.start()
        model.zoom.selectLens(at: 3)
        #expect(model.zoom.factor == 4)
        model.zoom.setZoom(100)
        #expect(model.zoom.factor == 40)
        #expect(model.zoom.activeLensIndex == 4)
        model.zoom.setZoom(0.1)
        #expect(model.zoom.factor == 0.5)
        #expect(service.calls == [.start(.back), .exposureBias(0), .rampZoom(4), .setZoom(40), .setZoom(0.5)])
    }

    @Test("Flash cycles through auto, on and off, and Live toggles")
    func indicators() {
        let model = makeModel()
        #expect(model.settings.flashMode == .auto)
        model.settings.cycleFlash()
        #expect(model.settings.flashMode == .alwaysOn)
        model.settings.cycleFlash()
        #expect(model.settings.flashMode == .off)
        model.settings.cycleFlash()
        #expect(model.settings.flashMode == .auto)
        model.settings.toggleLivePhoto()
        #expect(model.settings.isLivePhotoEnabled)
    }

    @Test("Setting values read as the sub-panels write them")
    func valueTitles() {
        let model = makeModel()
        model.settings.select(timer: .tenSeconds)
        model.settings.setExposureBias(-0.7)
        #expect(CameraSettingText(.system).value(of: .flash, in: model.settings) == "Auto")
        #expect(CameraSettingText(.system).value(of: .live, in: model.settings) == "Off")
        #expect(CameraSettingText(.system).value(of: .aspect, in: model.settings) == "4:3")
        #expect(CameraSettingText(.system).value(of: .timer, in: model.settings) == "10s")
        #expect(CameraSettingText(.system).value(of: .format, in: model.settings) == "HEIF")
        #expect(model.settings.exposureBias == -0.7)
    }

    @Test("The panel opens to the tiles, then a sub-panel, and a viewfinder tap closes it without focusing")
    func panel() async {
        let model = makeModel()
        await model.start()
        model.panel.showTiles()
        #expect(model.panel.presentation == .tiles)
        model.panel.showSubPanel(.aspect)
        #expect(model.panel.presentation == .subPanel(.aspect))
        model.viewfinderTapped(atUnitPoint: CGPoint(x: 0.5, y: 0.5), devicePoint: .zero)
        #expect(model.panel.presentation == .hidden)
        #expect(model.focus.reticle == nil)
        #expect(service.calls == [.start(.back), .exposureBias(0)])
    }

    @Test("A viewfinder tap focuses there and the reticle leaves after its lifetime")
    func focus() async throws {
        let model = makeModel()
        await model.start()
        let devicePoint = CGPoint(x: 0.6, y: 0.75)
        model.viewfinderTapped(atUnitPoint: CGPoint(x: 0.25, y: 0.4), devicePoint: devicePoint)
        #expect(model.focus.reticle?.location == CGPoint(x: 0.25, y: 0.4))
        #expect(service.calls.last == .focus(devicePoint))
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime - .milliseconds(1))
        await settleQueuedWork()
        #expect(model.focus.reticle != nil)
        clock.advance(by: .milliseconds(1))
        await settle { model.focus.reticle == nil }
    }

    @Test("Stopping the camera removes the reticle and cancels its timer")
    func stopClearsReticle() async {
        let model = makeModel()
        await model.start()
        model.viewfinderTapped(atUnitPoint: CGPoint(x: 0.5, y: 0.5), devicePoint: .zero)
        await clock.waitForSleepers()
        model.stop()
        #expect(model.focus.reticle == nil)
        #expect(clock.sleeperCount == 0)
        #expect(service.calls.last == .stop)
    }

    @Test("A second flip while the first is under way is ignored")
    func overlappingFlips() async {
        let model = makeModel()
        await model.start()
        service.holdsCalls = true
        let firstFlip = Task { await model.flipCamera() }
        await settle { service.heldCallCount == 1 }
        await model.flipCamera()
        service.holdsCalls = false
        service.releaseHeldCalls()
        await firstFlip.value
        #expect(service.calls.filter { $0 == .start(.front) }.count == 1)
        #expect(model.zoom.lenses.map(\.factor) == [1])
        await model.flipCamera()
        #expect(service.calls.suffix(2) == [.start(.back), .exposureBias(0)])
    }

    @Test("A capture hands one photo over, taken with the flash the user chose")
    func capture() async {
        var photos: [CameraCapture] = []
        let model = makeModel { photos.append($0) }
        await model.start()
        model.settings.cycleFlash()
        await model.capture()
        #expect(photos.count == 1)
        #expect(model.shutter.captureCount == 1)
        #expect(service.captureRequests.map(\.flashMode) == [.alwaysOn])
    }

    @Test("Flipping switches the camera, closes the dial and returns to the main lens")
    func flip() async {
        let model = makeModel()
        await model.start()
        model.zoom.setZoom(4)
        model.zoom.openDial()
        await model.flipCamera()
        #expect(service.calls.suffix(2) == [.start(.front), .exposureBias(0)])
        #expect(model.zoom.lenses.map(\.factor) == [1])
        #expect(model.zoom.factor == 1)
        #expect(model.zoom.isDialOpen == false)
    }
}
