//
//  CameraLifeCycleEdgeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

/// What a stop, a resume, an error of the session and a start that is cancelled leave behind.
@MainActor
@Suite("The camera stopped, resumed, failed or left while it starts", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraLifeCycleEdgeTests {
    let service = RecordingCameraService()
    let clock = ManualClock()

    @Test("Pressure that reaches a stopped pair starts nothing, and the camera resumes as the pair")
    func pressureAfterStop() async {
        var state = DualCameraFixture.keptState
        state.isDualCameraEnabled.value = true
        let model = makeCaptureModel(service: service, initialState: state, isDualCameraOffered: true)
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await model.start()
        #expect(model.session.isDualCameraOn)
        model.stop()
        let stopped = service.calls.count
        await service.simulate(.dualCameraPressureCritical)
        await settleQueuedWork()
        #expect(service.calls(after: stopped).isEmpty)
        #expect(model.notices.dualCameraNotice == nil)
        await model.resume()
        #expect(service.calls(after: stopped).first == .startDualCamera(main: .back))
        #expect(model.dualCamera.isOn)
    }

    @Test("A camera resumed after its automatic restarts ran out has them back")
    func resumeResetsRestarts() async {
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        var starts = service.startCount
        for restart in 1...AutomaticRestarts.limit {
            await service.simulate(.runtimeError(.mediaServicesReset))
            await settle { service.startCount == starts + restart }
        }
        await service.simulate(.runtimeError(.mediaServicesReset))
        #expect(model.session.failure == .stopped)
        model.stop()
        await model.resume()
        #expect(model.session.failure == nil)
        starts = service.startCount
        await service.simulate(.runtimeError(.mediaServicesReset))
        await settle { service.startCount == starts + 1 }
        #expect(model.session.failure == nil)
    }

    @Test("An error of the session takes the reticle away and stops its lifetime")
    func errorClearsReticle() async {
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        let point = CGPoint(x: 0.3, y: 0.6)
        model.viewfinderTapped(atUnitPoint: point, devicePoint: point)
        await clock.waitForSleepers()
        await service.simulate(.runtimeError(.hardwareFault))
        #expect(model.focus.reticle == nil)
        #expect(clock.sleeperCount == 0)
    }

    @Test("A screen that goes away while the camera opens never asks for the location")
    func cancelledBeforeTheLocationQuestion() async {
        let location = FakeLocation()
        let model = PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            onboarding: OnboardingModel(setting: .off, service: service, location: location),
            location: location
        ) { _ in }
        service.holdsCalls = true
        let start = Task { await model.start() }
        await settle { service.heldCallCount == 1 }
        start.cancel()
        service.holdsCalls = false
        service.releaseHeldCalls()
        await start.value
        #expect(location.requestCount == 0)
        model.close()
    }
}
