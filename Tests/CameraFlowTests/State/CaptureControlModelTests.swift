//
//  CaptureControlModelTests.swift
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
@Suite("Camera Control in the model", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CaptureControlModelTests {
    let service = RecordingCameraService()

    func makeStartedModel() async -> PhotoCameraModel {
        let model = PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            clock: ManualClock()
        ) { _ in }
        await model.start()
        return model
    }

    @Test("The zoom slider moves the lens row without sending the zoom back")
    func hardwareZoom() async {
        let model = await makeStartedModel()
        let callsBefore = service.calls
        await service.simulate(.captureControl(.zoomChanged(2.5)))
        #expect(model.zoom.factor == 2.5)
        #expect(model.zoom.activeLensIndex == 2)
        #expect(service.calls == callsBefore)
        #expect(service.captureControlLensIndexes == [2])
    }

    @Test("A zoom from the slider is kept inside the zoom range, and the kept zoom goes back to the camera")
    func hardwareZoomClamped() async {
        let model = await makeStartedModel()
        await service.simulate(.captureControl(.zoomChanged(100)))
        #expect(model.zoom.factor == 40)
        #expect(service.calls.last == .setZoom(40))
    }

    @Test("The exposure slider sets the bias without sending it back")
    func hardwareExposure() async {
        let model = await makeStartedModel()
        let callsBefore = service.calls
        await service.simulate(.captureControl(.exposureBiasChanged(1.3)))
        #expect(model.settings.exposureBias == 1.3)
        #expect(service.calls == callsBefore)
    }

    @Test("A bias outside the screen's range is clamped to it, and the clamped bias goes back to the camera")
    func hardwareExposureClamped() async {
        let model = await makeStartedModel()
        await service.simulate(.captureControl(.exposureBiasChanged(-5)))
        #expect(model.settings.exposureBias == -2)
        #expect(service.calls.last == .exposureBias(-2))
    }

    @Test("The exposure slider cannot change an exposure the app fixed: the fixed bias goes back to the camera")
    func hardwareExposureFixed() async {
        var state = CameraFlowInitialState()
        state.exposureBias = .fixed(0.5)
        let model = makeCaptureModel(service: service, initialState: state)
        await model.start()
        await service.simulate(.captureControl(.exposureBiasChanged(2)))
        #expect(model.settings.exposureBias == 0.5)
        #expect(service.calls.last == .exposureBias(0.5))
    }

    @Test("The lens picker switches the lens as a lens button does")
    func hardwareLens() async {
        let model = await makeStartedModel()
        await service.simulate(.captureControl(.lensSelected(index: 3)))
        #expect(model.zoom.factor == 4)
        #expect(service.calls.last == .rampZoom(4))
        #expect(service.captureControlLensIndexes == [3])
    }

    @Test("Zoom on the screen moves the lens picker only when it crosses into another lens")
    func screenZoomMovesPicker() async {
        let model = await makeStartedModel()
        model.zoom.setZoom(1.5)
        model.zoom.setZoom(1.8)
        model.zoom.selectLens(at: 0)
        model.zoom.turnDial(to: 9)
        #expect(service.captureControlLensIndexes == [0, 4])
    }

    @Test("Starting and flipping leave the picker to the session, which builds it on the main lens")
    func flipDoesNotPush() async {
        let model = await makeStartedModel()
        await model.flipCamera()
        await model.flipCamera()
        #expect(service.captureControlLensIndexes.isEmpty)
    }

    @Test(
        "The screen hides its controls only while the overlay is fullscreen",
        arguments: [
            (CaptureControlsOverlay.hidden, false),
            (CaptureControlsOverlay.shown, false),
            (CaptureControlsOverlay.fullscreen, true)
        ]
    )
    func overlay(overlay: CaptureControlsOverlay, hides: Bool) async {
        let model = await makeStartedModel()
        await service.simulate(.captureControl(.overlayChanged(overlay)))
        #expect(model.captureControls.overlay == overlay)
        #expect(model.captureControls.hidesControls == hides)
    }

    @Test("The capture buttons work once the camera runs and stop on a failure")
    func captureButtons() async {
        let model = await makeStartedModel()
        #expect(model.session.isRunning)
        await service.simulate(.runtimeError(CameraRuntimeError(message: "Stopped", isRecoverable: false)))
        #expect(model.session.isRunning == false)
    }

    @Test("The capture buttons are off before the camera starts")
    func captureButtonsBeforeStart() {
        let model = makeCaptureModel(service: service)
        #expect(model.session.isRunning == false)
    }
}
