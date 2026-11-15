//
//  ShutterReadinessTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The shutter and how ready the camera says it is for another photo: a busy camera takes no tap, as the stock
/// camera's shutter is inert then, and the shutter shows a wait that lasts.
@MainActor
@Suite("The shutter and the readiness of the camera", .temporaryDirectory, .timeLimit(.minutes(1)))
struct ShutterReadinessTests {
    let service = RecordingCameraService()

    @Test(
        "A camera busy with the photos before takes no tap, and a tap once it is ready again takes a photo",
        arguments: [CaptureReadiness.notReadyMomentarily, .waitingForCapture, .waitingForProcessing]
    )
    func busyCamera(readiness: CaptureReadiness) async throws {
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { captures.append($0) }
        await model.start()
        await service.simulate(.captureReadinessChanged(readiness))
        #expect(model.shutter.isBusy)
        #expect(model.shutter.takesTap == false)
        await model.capture()
        #expect(service.captureRequests.isEmpty)
        #expect(model.shutter.captureCount == 0)
        #expect(model.shutter.isCapturing == false)
        #expect(model.notice == nil)
        await service.simulate(.captureReadinessChanged(.ready))
        #expect(model.shutter.isBusy == false)
        await model.capture()
        #expect(service.captureRequests.count == 1)
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test(
        "The shutter shows a wait that lasts: dimmed while the camera takes a photo, with a spinner while it processes",
        arguments: [
            (CaptureReadiness.ready, ShutterBusyIndication.unchanged),
            (.notRunning, .unchanged),
            (.notReadyMomentarily, .unchanged),
            (.waitingForCapture, .dimmed),
            (.waitingForProcessing, .spinning)
        ]
    )
    func indication(readiness: CaptureReadiness, indication: ShutterBusyIndication) async {
        let model = makeCaptureModel(service: service)
        await model.start()
        await service.simulate(.captureReadinessChanged(readiness))
        #expect(model.shutter.readiness == readiness)
        #expect(model.shutter.busyIndication == indication)
    }

    @Test("A camera that says it does not run is not busy: the camera's own state stops or holds a tap")
    func notRunningIsNotBusy() async throws {
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { captures.append($0) }
        await model.start()
        await service.simulate(.captureReadinessChanged(.notRunning))
        #expect(model.shutter.isBusy == false)
        await model.capture()
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A camera that says nothing about its readiness is ready")
    func silentCamera() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        #expect(model.shutter.readiness == .ready)
        #expect(model.shutter.isBusy == false)
        #expect(model.shutter.busyIndication == .unchanged)
    }

    @Test("The shutter is busy from a tap until its shot reaches the camera, and takes the next tap from then on")
    func busyUntilTheShotReachesTheCamera() async throws {
        let gate = CallGate()
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, storage: FakeStorageSpace(gate: gate)) { captures.append($0) }
        await model.start()
        service.holdsCalls = true
        let capturing = Task { await model.capture() }
        await gate.arrival()
        #expect(model.shutter.isBusy)
        #expect(model.shutter.takesTap == false)
        #expect(model.shutter.photosInFlight == 1)
        await gate.open()
        await settle { service.heldCallCount == 1 }
        #expect(model.shutter.isBusy == false)
        #expect(model.shutter.takesTap)
        #expect(model.shutter.photosInFlight == 1)
        service.releaseHeldCalls()
        await capturing.value
        #expect(model.shutter.photosInFlight == 0)
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A tap stops a running countdown while the camera is busy")
    func countdownWhileBusy() async {
        var state = CameraFlowInitialState()
        state.timer.value = .threeSeconds
        let clock = ManualClock()
        let model = makeCaptureModel(service: service, initialState: state, clock: clock)
        await model.start()
        let capturing = Task { await model.capture() }
        await clock.waitForSleepers()
        await service.simulate(.captureReadinessChanged(.waitingForProcessing))
        #expect(model.shutter.isBusy)
        #expect(model.shutter.takesTap)
        await model.capture()
        await capturing.value
        #expect(model.shutter.isCountingDown == false)
        #expect(model.shutter.isCapturing == false)
        #expect(service.captureRequests.isEmpty)
    }
}
