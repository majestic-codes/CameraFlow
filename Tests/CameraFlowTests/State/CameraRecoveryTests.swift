//
//  CameraRecoveryTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("The camera after a runtime error of its session", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraRecoveryTests {
    let service = RecordingCameraService()

    // MARK: - Recoverable errors

    @Test("After a recoverable error the camera starts again on the same side at the same zoom, with no failure")
    func restartsAsItWas() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        await model.flipCamera()
        model.zoom.setZoom(2)
        let before = service.calls.count
        let starts = service.startCount
        await service.simulate(.runtimeError(.mediaServicesReset))
        await settle { service.startCount == starts + 1 && service.calls(after: before).contains(.setZoom(2)) }
        #expect(service.calls(after: before).first == .start(.front))
        #expect(service.calls(after: before).last == .setZoom(2))
        #expect(model.session.failure == nil)
        #expect(model.session.position == .front)
        #expect(model.session.isRunning)
    }

    @Test("After a recoverable error a dual camera starts again as a pair, with the same camera in the viewfinder")
    func restartsDualCamera() async {
        let model = makeCaptureModel(service: service, isDualCameraOffered: true)
        await model.start()
        await model.toggleDualCamera()
        await model.flipCamera()
        let before = service.calls.count
        let starts = service.startCount
        await service.simulate(.runtimeError(.mediaServicesReset))
        await settle { service.startCount == starts + 1 && model.dualCamera.isOn }
        #expect(service.calls(after: before).first == .startDualCamera(main: .front))
        #expect(model.session.isDualCameraOn)
        #expect(model.session.failure == nil)
    }

    @Test("A photo is taken again once the camera has recovered")
    func capturesAfterRecovery() async throws {
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { captures.append($0) }
        await model.start()
        let starts = service.startCount
        await service.simulate(.runtimeError(.mediaServicesReset))
        await settle { service.startCount == starts + 1 }
        await model.capture()
        #expect(model.notices.captureError == nil)
        let capture = try #require(captures.first)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A recoverable error stops a running countdown")
    func cancelsCountdown() async {
        var state = CameraFlowInitialState()
        state.timer = CameraFlowSetting(.threeSeconds)
        let model = makeCaptureModel(service: service, initialState: state)
        await model.start()
        let capture = Task { await model.capture() }
        await settle { model.shutter.isCountingDown }
        let starts = service.startCount
        await service.simulate(.runtimeError(.mediaServicesReset))
        await capture.value
        await settle { service.startCount == starts + 1 }
        #expect(model.shutter.isCountingDown == false)
        #expect(service.captureRequests.isEmpty)
    }

    @Test("A camera that cannot start again after a recoverable error shows why, and a retry starts it")
    func restartFails() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        model.zoom.setZoom(2)
        service.startError = .cannotUseCamera("Busy")
        await service.simulate(.runtimeError(.mediaServicesReset))
        await settle { model.session.failure != nil }
        #expect(model.session.failure == .unavailable(.cannotUseCamera("Busy")))
        #expect(model.session.failure?.isRetryable == true)
        service.startError = nil
        let before = service.calls.count
        await model.retry()
        #expect(service.calls(after: before).first == .start(.back))
        #expect(service.calls(after: before).last == .setZoom(2))
        #expect(model.session.failure == nil)
    }

    @Test("A session that keeps stopping is started again three times, then the failure is shown")
    func keepsStopping() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        let starts = service.startCount
        for restart in 1...3 {
            await service.simulate(.runtimeError(.mediaServicesReset))
            await settle { service.startCount == starts + restart }
            #expect(model.session.failure == nil)
        }
        await service.simulate(.runtimeError(.mediaServicesReset))
        #expect(model.session.failure == .stopped)
        #expect(service.startCount == starts + 3)
    }

    @Test("A retry gives the camera its automatic restarts back")
    func retryResetsRestarts() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        var starts = service.startCount
        for restart in 1...3 {
            await service.simulate(.runtimeError(.mediaServicesReset))
            await settle { service.startCount == starts + restart }
        }
        await service.simulate(.runtimeError(.mediaServicesReset))
        await model.retry()
        #expect(model.session.failure == nil)
        starts = service.startCount
        await service.simulate(.runtimeError(.mediaServicesReset))
        await settle { service.startCount == starts + 1 }
        #expect(model.session.failure == nil)
    }

    // MARK: - Errors that are not recoverable

    @Test("Any other error starts nothing and shows a failure the user can retry from")
    func failureWithoutRestart() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        let before = service.calls.count
        await service.simulate(.runtimeError(.hardwareFault))
        await settleQueuedWork()
        #expect(service.calls(after: before).isEmpty)
        #expect(model.session.failure == .stopped)
        #expect(model.session.failure?.isRetryable == true)
        #expect(model.session.isRunning == false)
    }

    @Test("A retry from a failure starts the camera again as it was")
    func retry() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        await model.flipCamera()
        await service.simulate(.runtimeError(.hardwareFault))
        let before = service.calls.count
        await model.retry()
        #expect(service.calls(after: before).first == .start(.front))
        #expect(model.session.failure == nil)
        #expect(model.session.isRunning)
    }

    @Test("A retry that fails keeps a failure to retry from")
    func retryFails() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        await service.simulate(.runtimeError(.hardwareFault))
        service.startError = .cannotUseCamera("Still broken")
        await model.retry()
        #expect(model.session.failure == .unavailable(.cannotUseCamera("Still broken")))
        service.startError = nil
        await model.retry()
        #expect(model.session.failure == nil)
    }

    @Test("A camera that could not start when the screen opened starts on a retry, at the zoom the screen opens with")
    func retryOpens() async {
        var state = CameraFlowInitialState()
        state.zoomFactor = 2
        let model = makeCaptureModel(service: service, initialState: state)
        service.startError = .cannotUseCamera("Busy")
        await model.start()
        #expect(model.session.failure == .unavailable(.cannotUseCamera("Busy")))
        #expect(model.session.capabilities == nil)
        service.startError = nil
        let before = service.calls.count
        await model.retry()
        #expect(service.calls(after: before).first == .start(.back))
        #expect(service.calls(after: before).last == .setZoom(2))
        #expect(model.session.failure == nil)
        #expect(model.session.capabilities != nil)
    }

    @Test("A retry does nothing while the camera runs or has no access")
    func retryWithoutFailure() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        let before = service.calls.count
        await model.retry()
        #expect(service.calls(after: before).isEmpty)
        let denied = RecordingCameraService()
        denied.authorization = .denied
        let deniedModel = makeCaptureModel(service: denied)
        await deniedModel.start()
        await deniedModel.retry()
        #expect(deniedModel.session.failure == .accessDenied)
        #expect(denied.calls.isEmpty)
    }

    @Test(
        "A failure offers a retry unless access is denied or restricted, or the device has no camera",
        arguments: [
            (CameraFailure.accessDenied, false),
            (.accessRestricted, false),
            (.unavailable(.noCamera), false),
            (.stopped, true)
        ]
    )
    func retryable(failure: CameraFailure, isRetryable: Bool) {
        #expect(failure.isRetryable == isRetryable)
    }

    // MARK: - A camera stopped on purpose

    @Test(
        "A camera stopped on purpose stays stopped whatever its session reports, and resumes as it was",
        arguments: [CameraRuntimeError.mediaServicesReset, .hardwareFault]
    )
    func stoppedCamera(error: CameraRuntimeError) async {
        let model = makeCaptureModel(service: service)
        await model.start()
        model.stop()
        let before = service.calls.count
        await service.simulate(.runtimeError(error))
        await settleQueuedWork()
        #expect(service.calls(after: before).isEmpty)
        #expect(model.session.failure == nil)
        await model.resume()
        #expect(service.calls(after: before).first == .start(.back))
        #expect(model.session.failure == nil)
    }

    @Test("A camera stopped while it was starting again does not run")
    func stoppedWhileRestarting() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        service.holdsCalls = true
        await service.simulate(.runtimeError(.mediaServicesReset))
        await settle { service.heldCallCount == 1 }
        model.stop()
        service.holdsCalls = false
        service.releaseHeldCalls()
        await settle { service.calls.count { $0 == .stop } == 2 }
        #expect(service.calls.last == .stop)
    }

    // MARK: - Interruptions

    @Test("An interruption that ends leaves the camera running with no failure and nothing started again")
    func interruptionEnds() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        let before = service.calls.count
        await service.simulate(.interrupted(.cameraUnavailableInBackground))
        #expect(model.session.interruption == .cameraUnavailableInBackground)
        await service.simulate(.interruptionEnded)
        #expect(model.session.interruption == nil)
        #expect(model.session.failure == nil)
        #expect(model.session.isRunning)
        #expect(service.calls(after: before).isEmpty)
    }
}
