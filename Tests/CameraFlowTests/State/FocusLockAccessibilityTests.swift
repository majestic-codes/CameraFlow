//
//  FocusLockAccessibilityTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

/// VoiceOver's action on the viewfinder: it locks the focus and the exposure at the reticle, or at the middle of the
/// picture without one, and ends a lock.
@MainActor
@Suite("AE/AF Lock from VoiceOver", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FocusLockAccessibilityTests {
    let service = RecordingCameraService()
    let clock = ManualClock()
    private let middle = CGPoint(x: 0.5, y: 0.5)

    private func makeStartedModel() async -> PhotoCameraModel {
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        return model
    }

    @Test("Without a reticle the action locks at the middle of the picture once the camera has settled, at once")
    func lockAtTheMiddle() async {
        let model = await makeStartedModel()
        model.toggleFocusLock()
        #expect(model.focus.lock == .settling)
        #expect(model.focus.reticle?.location == middle)
        #expect(model.focus.reticle?.devicePoint == middle)
        #expect(model.focus.isPressing == false)
        await settle { model.focus.lock == .locked }
        #expect(service.calls.last == .lockFocusAndExposure(middle))
        #expect(clock.sleeperCount == 0)
    }

    @Test("The action locks at the reticle that is shown, at its point of the camera, and keeps it past its lifetime")
    func lockAtTheReticle() async {
        let model = await makeStartedModel()
        let point = CGPoint(x: 0.2, y: 0.8)
        let devicePoint = CGPoint(x: 0.8, y: 0.8)
        model.viewfinderTapped(atUnitPoint: point, devicePoint: devicePoint)
        let reticle = model.focus.reticle
        model.toggleFocusLock()
        #expect(model.focus.reticle == reticle)
        await settle { model.focus.lock == .locked }
        #expect(service.calls.last == .lockFocusAndExposure(devicePoint))
        clock.advance(by: FocusModel.reticleLifetime)
        await settleQueuedWork()
        #expect(model.focus.reticle == reticle)
    }

    @Test("The action ends a lock: the camera focuses and exposes by itself again and the reticle goes")
    func unlockHeldLock() async {
        let model = await makeStartedModel()
        model.toggleFocusLock()
        await settle { model.focus.lock == .locked }
        model.toggleFocusLock()
        #expect(model.focus.lock == nil)
        #expect(model.focus.reticle == nil)
        #expect(service.calls.last == .resetFocus)
    }

    @Test("The action ends a lock that still settles, and the camera's later answer changes nothing")
    func unlockSettlingLock() async {
        service.holdsFocusLock = true
        let model = await makeStartedModel()
        model.toggleFocusLock()
        await settle { service.isFocusLockHeld }
        model.toggleFocusLock()
        #expect(model.focus.lock == nil)
        #expect(service.isFocusLockHeld == false)
        await settleQueuedWork()
        #expect(model.focus.lock == nil)
        #expect(model.focus.reticle == nil)
    }

    @Test("The action twice in one turn asks the camera for no lock, and leaves it focusing by itself")
    func lockAndUnlockAtOnce() async {
        let model = await makeStartedModel()
        let callCount = service.calls.count
        model.toggleFocusLock()
        model.toggleFocusLock()
        await settleQueuedWork()
        #expect(service.calls(after: callCount) == [.resetFocus])
        #expect(model.focus.lock == nil)
    }

    @Test("Over a camera that does not run the action locks nothing")
    func notRunning() async {
        service.authorization = .denied
        let model = await makeStartedModel()
        model.toggleFocusLock()
        #expect(model.focus.lock == nil)
        #expect(model.focus.reticle == nil)
        #expect(service.calls.isEmpty)
    }
}
