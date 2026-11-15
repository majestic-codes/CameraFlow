//
//  CameraLifeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// The life of the camera in a flow: a camera that was refused or closed never starts again, and one the flow
/// stopped while it was starting does not run.
@MainActor
@Suite("The life of the camera in the flow", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraLifeTests {
    let service = RecordingCameraService()

    private static func isStart(_ call: RecordingCameraService.Call) -> Bool {
        switch call {
        case .start, .startDualCamera: true
        default: false
        }
    }

    /// Whether a camera was started after the camera was last stopped.
    private var startsAfterLastStop: Bool {
        guard let lastStop = service.calls.lastIndex(of: .stop) else { return service.startCount > 0 }
        return service.calls[lastStop...].contains(where: Self.isStart)
    }

    // MARK: - Refused and closed

    @Test(
        "A refused camera keeps its failure: the flip, the circle and a retry start nothing",
        arguments: [(CameraAuthorization.denied, CameraFailure.accessDenied), (.restricted, .accessRestricted)]
    )
    func refusedCamera(authorization: CameraAuthorization, failure: CameraFailure) async {
        service.authorization = authorization
        let model = makeCaptureModel(service: service, isDualCameraOffered: true)
        await model.start()
        await model.flipCamera()
        await model.toggleDualCamera()
        await model.retry()
        #expect(model.session.failure == failure)
        #expect(model.session.life == .refused)
        #expect(service.startCount == 0)
        #expect(model.session.isActive == false)
        #expect(model.dualCamera.isToggleEnabled == false)
    }

    @Test("A closed camera starts no more: the flip, the circle, a resume and a recoverable error start nothing")
    func closedCamera() async {
        let model = makeCaptureModel(service: service, isDualCameraOffered: true)
        await model.start()
        #expect(model.dualCamera.isToggleEnabled)
        model.close()
        let starts = service.startCount
        await model.flipCamera()
        await model.toggleDualCamera()
        await model.resume()
        await service.simulate(.runtimeError(.mediaServicesReset))
        await settleQueuedWork()
        #expect(service.startCount == starts)
        #expect(model.session.life == .closed)
        #expect(model.dualCamera.isToggleEnabled == false)
    }

    @Test("A flow whose set was handed over starts its camera no more, and stays in the review")
    func afterHandOver() async throws {
        let harness = FlowHarness(service: service)
        let flow = try await harness.makeReviewedFlow(photoCount: 1)
        await flow.accept()
        let starts = service.startCount
        await flow.select(.shooting)
        await flow.camera.flipCamera()
        await flow.camera.toggleDualCamera()
        await flow.camera.retry()
        await flow.camera.resume()
        #expect(service.startCount == starts)
        #expect(flow.mode == .review)
        #expect(flow.canShowShooting == false)
        let handedOver = try #require(harness.outcome.handedOver.first)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("Leaving the flow closes its camera: a running self-timer takes no photo, and nothing starts it again")
    func exitDuringCountdown() async {
        let sensor = ManualAttitudeSensor()
        let harness = FlowHarness(service: service)
        var state = CameraFlowInitialState()
        state.timer = CameraFlowSetting(.threeSeconds)
        let flow = harness.makeFlow(initialState: state, attitudeSensor: sensor)
        await flow.camera.start()
        let shutter = Task { await flow.camera.capture() }
        await settle { flow.camera.shutter.isCountingDown }
        flow.requestExit()
        await shutter.value
        #expect(harness.outcome.exitCount == 1)
        #expect(service.calls.last == .stop)
        #expect(service.captureRequests.isEmpty)
        #expect(flow.camera.delivery.isClosed)
        #expect(sensor.isRunning == false)
        await flow.camera.flipCamera()
        await flow.camera.resume()
        #expect(startsAfterLastStop == false)
    }

    // MARK: - Stopped while it starts

    @Test("A stop while the circle fails to come on leaves the camera stopped, with no start after the stop")
    func stopDuringFailingPair() async {
        let model = makeCaptureModel(service: service, isDualCameraOffered: true)
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await model.start()
        service.dualStartError = .dualCameraUnavailable("No pair fits")
        service.holdsCalls = true
        let switching = Task { await model.toggleDualCamera() }
        await settle { service.heldCallCount == 1 }
        model.stop()
        service.holdsCalls = false
        service.releaseHeldCalls()
        await switching.value
        #expect(service.calls.last == .stop)
        #expect(startsAfterLastStop == false)
        #expect(model.session.life == .stopped)
    }

    @Test("A flip of the pair that fails while the camera is stopped leaves it stopped")
    func stopDuringFailingSwap() async {
        let model = makeCaptureModel(service: service, isDualCameraOffered: true)
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await model.start()
        await model.toggleDualCamera()
        service.dualStartError = .dualCameraUnavailable("The pair stopped")
        service.holdsCalls = true
        let flipping = Task { await model.flipCamera() }
        await settle { service.heldCallCount == 1 }
        model.stop()
        service.holdsCalls = false
        service.releaseHeldCalls()
        await flipping.value
        #expect(service.calls.last == .stop)
        #expect(startsAfterLastStop == false)
    }

    @Test("The check mark during a start of the pair leaves the closed camera stopped")
    func acceptDuringPairStart() async throws {
        let harness = FlowHarness(service: service)
        let flow = harness.makeFlow(isDualCameraOffered: true)
        flow.camera.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await flow.camera.start()
        await flow.camera.capture()
        service.holdsCalls = true
        let switching = Task { await flow.camera.toggleDualCamera() }
        await settle { service.heldCallCount == 1 }
        await flow.accept()
        service.holdsCalls = false
        service.releaseHeldCalls()
        await switching.value
        #expect(service.calls.last == .stop)
        #expect(startsAfterLastStop == false)
        let handedOver = try #require(harness.outcome.handedOver.first)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    // MARK: - A pause that goes with its session

    @Test("A pause ends with the camera the flow stops: the camera resumed takes a photo")
    func pauseEndsWithStop() async throws {
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { captures.append($0) }
        await model.start()
        await service.simulate(.interrupted(.cameraInUseByAnotherClient))
        await settle { model.session.interruption != nil }
        model.stop()
        #expect(model.session.interruption == nil)
        await model.resume()
        await model.capture()
        #expect(service.captureRequests.count == 1)
        #expect(model.notices.captureError == nil)
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A pause of the pair ends with the pair: the single camera after the circle goes off takes a photo")
    func pauseEndsWithPair() async throws {
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, isDualCameraOffered: true) { captures.append($0) }
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await model.start()
        await model.toggleDualCamera()
        await service.simulate(.interrupted(.cameraInUseByAnotherClient))
        await settle { model.session.interruption != nil }
        await model.toggleDualCamera()
        #expect(model.session.isDualCameraOn == false)
        await model.capture()
        #expect(model.notices.captureError == nil)
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A pair paused under pressure gives way to the single camera, which takes a photo")
    func pauseEndsUnderPressure() async throws {
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, isDualCameraOffered: true) { captures.append($0) }
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await model.start()
        await model.toggleDualCamera()
        await service.simulate(.interrupted(.cameraUnavailableUnderPressure))
        await settle { model.session.interruption != nil }
        await model.dualCameraUnderPressure()
        #expect(model.session.isDualCameraOn == false)
        #expect(model.session.interruption == nil)
        await model.capture()
        #expect(service.captureRequests.count == 1)
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    // MARK: - The zoom while a camera starts

    @Test("A zoom asked for while the camera flips reaches neither camera, and the lens buttons stay true")
    func zoomDuringFlip() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        service.holdsCalls = true
        let flipping = Task { await model.flipCamera() }
        await settle { service.heldCallCount == 1 }
        model.zoom.setZoom(3)
        model.zoom.selectLens(at: 0)
        service.holdsCalls = false
        service.releaseHeldCalls()
        await flipping.value
        let zooms = service.calls.filter { call in
            switch call {
            case .setZoom, .rampZoom: true
            default: false
            }
        }
        #expect(zooms.isEmpty)
        #expect(model.zoom.factor == 1)
        model.zoom.setZoom(2)
        #expect(service.calls.last == .setZoom(2))
    }

    // MARK: - The compass

    @Test("The compass hears of the phone only when it turns to another quarter")
    func compassFollowsQuarters() async {
        let sensor = ManualAttitudeSensor()
        let compass = FakeHeading()
        let model = makeCaptureModel(service: service, attitudeSensor: sensor, heading: compass)
        await model.start()
        for _ in 1...10 {
            sensor.simulate(.upright(in: .portrait))
        }
        #expect(compass.orientations.isEmpty)
        for _ in 1...10 {
            sensor.simulate(.upright(in: .landscapeLeft))
        }
        #expect(compass.orientations == [.landscapeLeft])
        model.close()
    }
}
