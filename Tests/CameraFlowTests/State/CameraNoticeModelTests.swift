//
//  CameraNoticeModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("What the camera says over the viewfinder", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraNoticeModelTests {
    let service = RecordingCameraService()

    @Test("The camera says one thing at a time: a pause, then a failed capture, then the circle, then the saving")
    func order() async {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .denied)
        let saving = CaptureTestSupport.makeLibrarySaving(isOn: false, writer: writer)
        let model = makeCaptureModel(service: service, librarySaving: saving)
        await model.start()
        #expect(model.notice == nil)
        await model.settings.toggleLibrarySaving()
        #expect(model.notice == .librarySavingRefused(.accessDenied))
        model.notices.showDualCameraNotice(.unavailable)
        #expect(model.notice == .dualCamera(.unavailable))
        model.notices.captureFailed(with: .notRunning)
        #expect(model.notice == .captureFailed(.notRunning))
        await service.simulate(.interrupted(.cameraInUseByAnotherClient))
        #expect(model.notice == .interrupted(.cameraInUseByAnotherClient))
        await service.simulate(.interruptionEnded)
        #expect(model.notice == .captureFailed(.notRunning))
        model.clearNotices()
        #expect(model.notice == nil)
        #expect(model.notices.dualCameraNotice == nil)
        #expect(saving.refusal == nil)
    }

    @Test("A change the user makes to a setting clears what the camera said, and a pause stays until it ends")
    func userChangeClears() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        model.notices.captureFailed(with: .notRunning)
        await service.simulate(.interrupted(.cameraInUseByAnotherClient))
        model.settings.cycleFlash()
        #expect(model.notice == .interrupted(.cameraInUseByAnotherClient))
        await service.simulate(.interruptionEnded)
        #expect(model.notice == nil)
    }

    @Test("A setting the user does not change, or the Camera Control moves, leaves what the camera said")
    func unchangedSettingKeeps() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        model.notices.captureFailed(with: .notRunning)
        model.settings.select(timer: model.settings.timer)
        await service.simulate(.captureControl(.exposureBiasChanged(1)))
        #expect(model.notice == .captureFailed(.notRunning))
    }

    @Test("A camera that starts again clears what was said about the one before")
    func startClears() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        model.notices.showDualCameraNotice(.turnedOffUnderPressure)
        await model.flipCamera()
        #expect(model.notice == nil)
    }

    @Test("A tap the set refuses replaces the failed capture and leaves the rest of what the camera said")
    func refusedTapKeepsTheRest() async {
        let flow = FlowHarness().makeFlow(limit: .maximum(1))
        let camera = flow.camera
        await camera.start()
        await camera.capture()
        camera.notices.showDualCameraNotice(.unavailable)
        await camera.capture()
        #expect(camera.notices.captureError == .captureLimitReached(1))
        #expect(camera.notices.dualCameraNotice == .unavailable)
        flow.photoSet.discard()
    }

    @Test("A tap that only cancels the self-timer leaves what the camera said")
    func cancellingTapKeeps() async {
        var state = CameraFlowInitialState()
        state.timer.value = .threeSeconds
        let clock = ManualClock()
        let model = makeCaptureModel(service: service, initialState: state, clock: clock)
        await model.start()
        let capture = Task {
            await model.capture()
        }
        await clock.waitForSleepers()
        model.notices.showDualCameraNotice(.unavailable)
        await model.capture()
        await capture.value
        #expect(model.notice == .dualCamera(.unavailable))
        #expect(model.shutter.captureCount == 0)
    }
}
