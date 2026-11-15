//
//  CameraScreenStateTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("What the screen derives from the model", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraScreenStateTests {
    // MARK: - Availability

    @Test("The Format panel offers what the camera offers")
    func offeredFormats() async {
        let service = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.narrowCapabilities)
        let model = makeCaptureModel(service: service)
        #expect(model.settings.offeredPhotoFormats.isEmpty)
        await model.start()
        #expect(model.settings.offeredPhotoFormats == [.heif])
        await model.flipCamera()
        await model.flipCamera()
        #expect(model.settings.deliversPhotos(within: model.settings.output))
    }

    @Test("RAW makes Live Photo unselectable and takes the photo without it")
    func liveWithRAW() async throws {
        let service = RecordingCameraService()
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled.value = true
        state.photoFormat.value = .raw
        let model = makeCaptureModel(service: service, initialState: state)
        await model.start()
        #expect(model.settings.isLivePhotoAvailable)
        #expect(model.settings.isLivePhotoSelectable == false)
        #expect(model.settings.isLivePhotoInEffect == false)
        await model.capture()
        #expect(model.notices.captureError == nil)
        let request = try #require(service.captureRequests.first)
        #expect(request.isLivePhotoEnabled == false)
        model.settings.select(photoFormat: .heif)
        #expect(model.settings.isLivePhotoInEffect)
    }

    @Test("Live Photo cannot be selected on a camera without it")
    func liveUnavailable() async {
        let service = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.narrowCapabilities)
        let model = makeCaptureModel(service: service)
        await model.start()
        #expect(model.settings.isLivePhotoSelectable == false)
    }

    // MARK: - Notice

    @Test("The notice follows the interruption, then the capture error, and clears with them")
    func notice() async {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service)
        await model.start()
        #expect(model.notice.map(CameraNoticeText(.system).message) == nil)
        await service.simulate(.interrupted(.cameraInUseByAnotherClient))
        #expect(model.notice.map(CameraNoticeText(.system).message) == "Camera in use by another app")
        await model.capture()
        await service.simulate(.interruptionEnded)
        #expect(model.notice.map(CameraNoticeText(.system).message) == "Camera in use by another app")
        await model.capture()
        #expect(model.notice.map(CameraNoticeText(.system).message) == nil)
    }

    @Test("A failed capture says why")
    func captureErrorNotice() async {
        let service = RecordingCameraService()
        service.captureError = .captureFailed("Test")
        let model = makeCaptureModel(service: service)
        await model.start()
        await model.capture()
        #expect(model.notice.map(CameraNoticeText(.system).message) == "Photo could not be taken")
    }

    // MARK: - Countdown

    @Test("The countdown shows the seconds left and clears when cancelled")
    func countdown() async throws {
        let service = RecordingCameraService()
        var state = CameraFlowInitialState()
        state.timer.value = .threeSeconds
        let clock = ManualClock()
        let model = makeCaptureModel(service: service, initialState: state, clock: clock)
        #expect(model.shutter.countdownSeconds == nil)
        let capture = Task {
            await model.capture()
        }
        await clock.waitForSleepers()
        #expect(model.shutter.countdownSeconds == 3)
        model.shutter.cancelCountdown()
        await capture.value
        #expect(model.shutter.countdownSeconds == nil)
        #expect(model.shutter.captureCount == 0)
    }

    @Test("A device without a camera is not asked for one again")
    func noCameraIsNotRetried() async {
        let service = RecordingCameraService()
        service.cameraPositions = []
        let model = makeCaptureModel(service: service)
        await model.start()
        #expect(model.session.failure == .unavailable(.noCamera))
        await model.retry()
        #expect(service.calls.isEmpty)
        #expect(service.authorizationRequestCount == 0)
        #expect(model.session.failure == .unavailable(.noCamera))
    }
}
