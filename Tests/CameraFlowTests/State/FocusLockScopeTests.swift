//
//  FocusLockScopeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

/// AE/AF Lock on each camera: what the running camera can lock, the exposure alone on a front camera with a fixed
/// focus, and nothing on a camera that can lock neither.
@MainActor
@Suite("What AE/AF Lock holds on each camera", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FocusLockScopeTests {
    let clock = ManualClock()
    private let point = CGPoint(x: 0.3, y: 0.6)
    private let devicePoint = CGPoint(x: 0.6, y: 0.7)

    /// The front camera of the simulated iPhone, locking what the test says.
    private static func capabilities(locking adjustments: LockableAdjustments?) -> PhotoCaptureCapabilities {
        let front = SimulatedCameraService.iPhoneFrontPhotoCapabilities
        return PhotoCaptureCapabilities(
            flashModes: front.flashModes,
            isLivePhotoSupported: front.isLivePhotoSupported,
            exposureBiasRange: front.exposureBiasRange,
            formats: front.formats,
            encodesHEVC: front.encodesHEVC,
            resolution: front.resolution,
            lockableAdjustments: adjustments
        )
    }

    @Test("The focus takes what the running camera can lock, again with every camera that starts")
    func followsTheCamera() async {
        let service = RecordingCameraService(frontPhotoCapabilities: Self.capabilities(locking: .exposure))
        let model = makeCaptureModel(service: service, clock: clock)
        #expect(model.focus.lockableAdjustments == nil)
        await model.start()
        #expect(model.focus.lockableAdjustments == .focusAndExposure)
        await model.flipCamera()
        #expect(model.focus.lockableAdjustments == .exposure)
        await model.flipCamera()
        #expect(model.focus.lockableAdjustments == .focusAndExposure)
    }

    @Test("A long press on a camera that locks the exposure alone takes its lock as on any other camera")
    func exposureAlone() async {
        let service = RecordingCameraService(backPhotoCapabilities: Self.capabilities(locking: .exposure))
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: devicePoint)
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.lockDelay)
        await settle { model.focus.lock == .locked }
        #expect(model.focus.lockableAdjustments == .exposure)
        #expect(service.calls.contains(.lockFocusAndExposure(devicePoint)))
    }

    @Test("A camera that can lock neither takes no long press and no lock from VoiceOver, and asks the camera nothing")
    func nothingToLock() async {
        let service = RecordingCameraService(backPhotoCapabilities: Self.capabilities(locking: nil))
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        let calls = service.calls.count
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: devicePoint)
        #expect(model.focus.lock == nil)
        #expect(model.focus.isPressing == false)
        #expect(model.focus.reticle == nil)
        model.viewfinderPressEnded()
        model.toggleFocusLock()
        await settleQueuedWork()
        #expect(model.focus.lock == nil)
        #expect(service.calls(after: calls).isEmpty)
    }
}
