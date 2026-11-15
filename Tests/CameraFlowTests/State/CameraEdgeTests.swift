//
//  CameraEdgeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// What the camera does with an event that finds it in another state than the event assumes.
@MainActor
@Suite("Camera events that come at the wrong moment", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraEdgeTests {
    private let service = RecordingCameraService()

    // MARK: - Pressure on the pair

    @Test("Pressure reported while one camera runs alone changes nothing")
    func pressureWithoutCircle() async {
        let model = makeCaptureModel(service: service, isDualCameraOffered: true)
        await model.start()
        let before = service.calls.count
        await service.simulate(.dualCameraPressureCritical)
        await settleQueuedWork()
        #expect(service.calls(after: before).isEmpty)
        #expect(model.notices.dualCameraNotice == nil)
        #expect(model.dualCamera.isOn == false)
    }

    @Test("Under pressure a single camera that cannot start becomes the failure, without the notice about cooling down")
    func pressureAndFailedStart() async {
        let model = makeCaptureModel(service: service, isDualCameraOffered: true)
        await model.start()
        await model.toggleDualCamera()
        #expect(model.dualCamera.isOn)
        service.startError = .cannotUseCamera("The camera is held by another app")
        await service.simulate(.dualCameraPressureCritical)
        await settle { model.session.failure != nil }
        #expect(model.session.failure == .unavailable(.cannotUseCamera("The camera is held by another app")))
        #expect(model.notices.dualCameraNotice == nil)
        #expect(model.dualCamera.isSwitching == false)
    }

    // MARK: - An error of a camera stopped meanwhile

    @Test("A restart that waits for another to end does not start a camera stopped meanwhile")
    func stoppedBeforeTheRestart() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        service.holdsCalls = true
        await service.simulate(.runtimeError(.mediaServicesReset))
        await settle { service.heldCallCount == 1 }
        let starts = service.startCount
        await service.simulate(.runtimeError(.mediaServicesReset))
        model.stop()
        service.holdsCalls = false
        service.releaseHeldCalls()
        await settle { service.calls.last == .stop && service.calls.count { $0 == .stop } == 2 }
        await settleQueuedWork()
        #expect(service.startCount == starts)
        #expect(service.calls.last == .stop)
        #expect(model.session.failure == nil)
    }

    @Test("A camera stopped while an error it would recover from is on its way is not started again")
    func stoppedBeforeTheErrorArrives() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        let before = service.calls.count
        service.post(.runtimeError(.mediaServicesReset))
        model.stop()
        await service.waitForPostedEvents()
        await settleQueuedWork()
        #expect(service.calls(after: before) == [.stop])
        #expect(model.session.failure == nil)
    }

    @Test("A shutter tap that reaches the camera after its session failed hands no photo over")
    func tapAfterTheSessionFailed() async throws {
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { captures.append($0) }
        let photo = CapturedPhoto(imageData: try DevicePhotoFixture.make(), encoding: .heif, livePhotoMovieURL: nil)
        service.deliveredPhoto = photo
        await model.start()
        await service.simulate(.runtimeError(.hardwareFault))
        await model.capture()
        #expect(captures.isEmpty)
    }

    @Test("A shutter tap after the session failed, before the camera heard of it, fails as not running")
    func tapBeforeTheErrorArrives() async {
        let model = makeCaptureModel(service: service, storage: ImmediateStorageSpace())
        await model.start()
        service.post(.runtimeError(.hardwareFault))
        await model.capture()
        #expect(service.captureRequests.count == 1)
        #expect(model.notices.captureError == .notRunning)
        await service.waitForPostedEvents()
        #expect(model.session.failure == .stopped)
    }

    // MARK: - Exposure drag without a reticle

    @Test("An exposure drag with no reticle on the screen holds nothing, and its end shows none")
    func exposureDragWithoutReticle() async {
        let clock = ManualClock()
        let focus = FocusModel(service: service, clock: clock)
        focus.beginAdjustingExposure()
        #expect(focus.isAdjustingExposure == false)
        focus.endAdjustingExposure()
        await settleQueuedWork()
        #expect(focus.reticle == nil)
        #expect(clock.sleeperCount == 0)
    }

    @Test("The end of an exposure drag that never began leaves the reticle its lifetime as it runs")
    func endWithoutDrag() async {
        let clock = ManualClock()
        let focus = FocusModel(service: service, clock: clock)
        focus.focus(atUnitPoint: CGPoint(x: 0.5, y: 0.5), devicePoint: CGPoint(x: 0.5, y: 0.5))
        await settle { clock.sleeperCount == 1 }
        clock.advance(by: FocusModel.reticleLifetime - .seconds(1))
        focus.endAdjustingExposure()
        await settleQueuedWork()
        #expect(focus.reticle != nil)
        clock.advance(by: .seconds(1))
        await settle { focus.reticle == nil }
    }
}

/// A volume with plenty of room that answers on the main actor without giving up its turn, so a shutter tap reaches
/// the camera service before the camera model hears an event on its way. The device's volume is read away from the
/// main actor, and such an event reaches the model meanwhile.
@MainActor
private final class ImmediateStorageSpace: StorageSpace {

    func availableBytes() async throws -> Int64 {
        FakeStorageSpace.plenty
    }
}
