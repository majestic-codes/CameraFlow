//
//  PinchZoomAvailabilityTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Pinch zoom: when it is taken and which camera it zooms", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PinchZoomAvailabilityTests {
    let service = RecordingCameraService()
    let clock = ManualClock()

    private func makeStartedModel(isDualCameraOn: Bool = false) async -> PhotoCameraModel {
        var state = DualCameraFixture.keptState
        state.isDualCameraEnabled.value = isDualCameraOn
        let model = makeCaptureModel(service: service, initialState: state, isDualCameraOffered: true)
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await model.start()
        return model
    }

    private func makePinch(over model: PhotoCameraModel) -> (pinch: ZoomPinchInteraction, dial: ZoomDialInteraction) {
        let dial = ZoomDialInteraction(zoom: model.zoom, clock: clock)
        return (ZoomPinchInteraction(zoom: model.zoom, dial: dial), dial)
    }

    /// Factors the camera was set to at once, in order.
    private var setFactors: [CGFloat] {
        service.calls.compactMap { call in
            guard case let .setZoom(factor) = call else { return nil }
            return factor
        }
    }

    // MARK: - When

    @Test("A running camera takes the pinch, with a sub-panel open too")
    func running() async {
        let model = await makeStartedModel()
        #expect(model.acceptsPinchZoom)
        model.panel.showTiles()
        model.panel.showSubPanel(.format)
        #expect(model.acceptsPinchZoom)
    }

    @Test("A camera that has not started takes no pinch")
    func notStarted() {
        let model = makeCaptureModel(service: service)
        #expect(model.acceptsPinchZoom == false)
    }

    @Test("A camera that cannot start takes no pinch")
    func cannotStart() async {
        service.startError = .notRunning
        let model = makeCaptureModel(service: service)
        await model.start()
        #expect(model.session.failure != nil)
        #expect(model.acceptsPinchZoom == false)
    }

    @Test("A camera that stopped with a failure takes no pinch")
    func stopped() async {
        let model = await makeStartedModel()
        model.session.stopped()
        #expect(model.acceptsPinchZoom == false)
    }

    @Test("The grid of tiles, which hides the zoom control, takes the pinch away, and closing it gives it back")
    func tiles() async {
        let model = await makeStartedModel()
        model.panel.showTiles()
        #expect(model.acceptsPinchZoom == false)
        model.panel.dismiss()
        #expect(model.acceptsPinchZoom)
    }

    @Test("The Camera Control's fullscreen overlay, which hides the zoom control, takes the pinch away")
    func captureOverlay() async {
        let model = await makeStartedModel()
        await service.simulate(.captureControl(.overlayChanged(.fullscreen)))
        #expect(model.acceptsPinchZoom == false)
        await service.simulate(.captureControl(.overlayChanged(.hidden)))
        #expect(model.acceptsPinchZoom)
    }

    @Test("The introduction over the camera takes no pinch")
    func onboarding() {
        service.isAuthorizationDetermined = false
        let onboarding = OnboardingModel(setting: .automatic, service: service)
        let model = PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            onboarding: onboarding,
            files: CaptureTestSupport.makeFileStore()
        ) { _ in }
        #expect(onboarding.step == .camera)
        #expect(model.acceptsPinchZoom == false)
    }

    @Test("A pinch during the countdown of the timer zooms, as the dial does")
    func countdown() async {
        var state = CameraFlowInitialState()
        state.timer.value = .threeSeconds
        let model = makeCaptureModel(service: service, initialState: state, clock: clock)
        await model.start()
        let capture = Task { await model.capture() }
        await clock.waitForSleepers()
        #expect(model.shutter.countdownSeconds == 3)
        #expect(model.acceptsPinchZoom)
        model.shutter.cancelCountdown()
        await capture.value
    }

    // MARK: - Which camera

    @Test("With the circle on the pinch zooms the camera of the viewfinder over its range")
    func dualCameraMain() async {
        let model = await makeStartedModel(isDualCameraOn: true)
        #expect(model.dualCamera.isOn)
        #expect(model.session.position == .back)
        let (pinch, dial) = makePinch(over: model)
        pinch.began(isEnabled: model.acceptsPinchZoom)
        pinch.changed(magnification: 3)
        pinch.changed(magnification: 0.1)
        #expect(setFactors == [3, 0.5])
        #expect(model.zoom.factor == 0.5)
        dial.cancelTimers()
    }

    @Test("After a swap the pinch zooms the new camera of the viewfinder, from its main lens and over its range")
    func dualCameraSwapped() async {
        let model = await makeStartedModel(isDualCameraOn: true)
        let (pinch, dial) = makePinch(over: model)
        pinch.began(isEnabled: model.acceptsPinchZoom)
        pinch.changed(magnification: 3)
        pinch.ended()
        await model.flipCamera()
        #expect(model.dualCamera.isOn)
        #expect(model.session.position == .front)
        #expect(model.zoom.isDialOpen == false)
        #expect(model.zoom.factor == 1)
        pinch.began(isEnabled: model.acceptsPinchZoom)
        pinch.changed(magnification: 2)
        #expect(model.zoom.factor == 2)
        pinch.changed(magnification: 30)
        #expect(model.zoom.factor == 5)
        #expect(setFactors == [3, 2, 5])
        dial.cancelTimers()
    }
}
