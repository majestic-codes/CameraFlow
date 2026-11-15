//
//  CameraChangeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("One change of the camera at a time, and a camera that recovers", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraChangeTests {
    let service = RecordingCameraService()

    // MARK: - A camera that recovers

    @Test("A camera that ran long enough after a restart has its automatic restarts back")
    func recoveredCameraRestartsAgain() async {
        let clock = ManualClock()
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        var starts = service.startCount
        for restart in 1...3 {
            await service.simulate(.runtimeError(.mediaServicesReset))
            await settle { service.startCount == starts + restart && service.calls.last == .setZoom(1) }
        }
        clock.advance(by: AutomaticRestarts.recoveryInterval)
        starts = service.startCount
        for restart in 1...3 {
            await service.simulate(.runtimeError(.mediaServicesReset))
            await settle { service.startCount == starts + restart }
            #expect(model.session.failure == nil)
        }
        await service.simulate(.runtimeError(.mediaServicesReset))
        #expect(model.session.failure == .stopped)
    }

    @Test("A camera that stops again before it ran long enough keeps counting its restarts")
    func notYetRecovered() async {
        let clock = ManualClock()
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        let starts = service.startCount
        for restart in 1...3 {
            await service.simulate(.runtimeError(.mediaServicesReset))
            await settle { service.startCount == starts + restart && service.calls.last == .setZoom(1) }
            clock.advance(by: AutomaticRestarts.recoveryInterval - .seconds(1))
        }
        await service.simulate(.runtimeError(.mediaServicesReset))
        #expect(model.session.failure == .stopped)
        #expect(service.startCount == starts + 3)
    }

    // MARK: - One change of the camera at a time

    @Test("An error during a flip starts the camera again after the flip, never beside it")
    func errorDuringFlip() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        let before = service.calls.count
        service.holdsCalls = true
        let flip = Task { await model.flipCamera() }
        await settle { service.heldCallCount == 1 }
        await service.simulate(.runtimeError(.mediaServicesReset))
        await settleQueuedWork()
        #expect(service.calls(after: before) == [.start(.front)])
        #expect(service.heldCallCount == 1)
        service.holdsCalls = false
        service.releaseHeldCalls()
        await flip.value
        await settle { service.calls(after: before).count { $0 == .start(.front) } == 2 }
        let changes = service.calls(after: before).filter { $0 != .exposureBias(0) }
        #expect(changes == [.start(.front), .start(.front), .setZoom(1)])
        #expect(model.session.position == .front)
        #expect(model.session.failure == nil)
    }

    @Test("Pressure during a switch to the pair is not lost: the pair comes on, then goes off with the notice")
    func pressureDuringToggle() async {
        let model = makeCaptureModel(service: service, isDualCameraOffered: true)
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await model.start()
        let before = service.calls.count
        service.holdsCalls = true
        let toggle = Task { await model.toggleDualCamera() }
        await settle { service.heldCallCount == 1 }
        await service.simulate(.dualCameraPressureCritical)
        await settleQueuedWork()
        #expect(service.calls(after: before) == [.startDualCamera(main: .back)])
        service.holdsCalls = false
        service.releaseHeldCalls()
        await toggle.value
        await settle { model.notices.dualCameraNotice == .turnedOffUnderPressure }
        let starts = service.calls(after: before).filter { $0 != .exposureBias(0) }
        #expect(starts == [.startDualCamera(main: .back), .start(.back)])
        #expect(model.dualCamera.isOn == false)
        #expect(model.dualCamera.isSwitching == false)
    }

    @Test("A retry while the camera is being started again does nothing")
    func retryDuringRestart() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        await service.simulate(.runtimeError(.hardwareFault))
        let before = service.calls.count
        service.holdsCalls = true
        let retry = Task { await model.retry() }
        await settle { service.heldCallCount == 1 }
        await model.retry()
        #expect(service.calls(after: before) == [.start(.back)])
        service.holdsCalls = false
        service.releaseHeldCalls()
        await retry.value
        #expect(model.session.failure == nil)
    }

    @Test("A camera that never ran keeps the upright elements following the phone through the review and a retry")
    func retryFollowsAttitude() async {
        let sensor = ManualAttitudeSensor()
        let model = makeCaptureModel(service: service, attitudeSensor: sensor)
        service.startError = .cannotUseCamera("Busy")
        await model.start()
        model.stop()
        await model.resume()
        #expect(sensor.isRunning)
        service.startError = nil
        await model.retry()
        #expect(model.session.failure == nil)
        #expect(sensor.isRunning)
        sensor.simulate(DeviceGravity(towardRightEdge: -1, towardTopEdge: 0, outOfScreen: 0))
        #expect(model.orientation.elementRotation != .portrait)
    }
}
