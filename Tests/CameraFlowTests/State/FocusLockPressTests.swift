//
//  FocusLockPressTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

/// The stock AE/AF Lock set by a long press on the viewfinder: the camera focuses and exposes at the point, and the
/// lock takes once the press has held for the stock second and the camera has settled.
@MainActor
@Suite("AE/AF Lock by a long press", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FocusLockPressTests {
    let service = RecordingCameraService()
    let clock = ManualClock()
    let haptics = RecordingCameraHaptics()
    private let point = CGPoint(x: 0.3, y: 0.6)
    private let devicePoint = CGPoint(x: 0.6, y: 0.7)

    private func makeStartedModel() async -> PhotoCameraModel {
        let model = makeCaptureModel(service: service, haptics: haptics, clock: clock)
        await model.start()
        return model
    }

    /// Presses the viewfinder until the lock takes, with a camera that settles at once.
    private func press(on model: PhotoCameraModel) async {
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: devicePoint)
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.lockDelay)
        await settle { model.focus.lock == .locked }
    }

    @Test("A long press focuses and exposes at the point and marks it with the reticle of a press, without a lock yet")
    func pressBegins() async {
        let model = await makeStartedModel()
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: devicePoint)
        #expect(model.focus.lock == .pressing)
        #expect(model.focus.isPressing)
        #expect(model.focus.reticle?.location == point)
        #expect(model.focus.reticle?.devicePoint == devicePoint)
        #expect(model.focus.reticle?.kind == .press)
        await settle { service.calls.last == .lockFocusAndExposure(devicePoint) }
        await settleQueuedWork()
        #expect(model.focus.lock == .pressing)
        #expect(haptics.events.isEmpty)
    }

    @Test("The lock takes when the press has held for the stock second, over a camera that settled before")
    func lockTakesAfterTheDelay() async {
        let model = await makeStartedModel()
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: devicePoint)
        await clock.waitForSleepers()
        await settleQueuedWork()
        clock.advance(by: FocusModel.lockDelay - .milliseconds(1))
        await settleQueuedWork()
        #expect(model.focus.lock == .pressing)
        clock.advance(by: .milliseconds(1))
        await settle { model.focus.lock == .locked }
        #expect(model.focus.isPressing)
    }

    @Test("A camera that settles after the press held long enough takes the lock then, the finger up or not")
    func cameraSettlesLate() async {
        service.holdsFocusLock = true
        let model = await makeStartedModel()
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: devicePoint)
        await settle { service.isFocusLockHeld }
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.lockDelay)
        await settle { model.focus.lock == .settling }
        model.viewfinderPressEnded()
        #expect(model.focus.lock == .settling)
        #expect(model.focus.isPressing == false)
        service.settleFocusLock()
        await settle { model.focus.lock == .locked }
        #expect(service.calls.contains(.unlockFocusAndExposure) == false)
    }

    @Test("A finger that lets go before the stock second gives the lock up, and the point keeps a tap's reticle")
    func earlyReleaseGivesUp() async {
        let model = await makeStartedModel()
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: devicePoint)
        await clock.waitForSleepers()
        await settleQueuedWork()
        clock.advance(by: FocusModel.lockDelay - .milliseconds(1))
        model.viewfinderPressEnded()
        #expect(model.focus.lock == nil)
        #expect(model.focus.isPressing == false)
        #expect(service.calls.last == .unlockFocusAndExposure)
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime)
        await settle { model.focus.reticle == nil }
        #expect(model.focus.lock == nil)
    }

    @Test("A lock keeps the reticle for good once the finger has let go, past its lifetime")
    func lockKeepsTheReticle() async {
        let model = await makeStartedModel()
        await press(on: model)
        model.viewfinderPressEnded()
        await settleQueuedWork()
        #expect(clock.sleeperCount == 0)
        clock.advance(by: FocusModel.reticleLifetime * 3)
        await settleQueuedWork()
        #expect(model.focus.reticle?.location == point)
        #expect(model.focus.lock == .locked)
    }

    @Test("A new long press over a lock gives it up and locks at its own point")
    func newPressMovesTheLock() async {
        let model = await makeStartedModel()
        await press(on: model)
        model.viewfinderPressEnded()
        let other = CGPoint(x: 0.8, y: 0.2)
        model.viewfinderPressBegan(atUnitPoint: other, devicePoint: other)
        #expect(model.focus.lock == .pressing)
        #expect(model.focus.reticle?.location == other)
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.lockDelay)
        await settle { model.focus.lock == .locked }
        #expect(service.calls.filter { $0 == .lockFocusAndExposure(other) }.count == 1)
    }

    @Test("A long press while the control panel is open closes the panel and locks nothing")
    func pressClosesThePanel() async {
        let model = await makeStartedModel()
        model.panel.showTiles()
        let callCount = service.calls.count
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: devicePoint)
        #expect(model.panel.isOpen == false)
        #expect(model.focus.lock == nil)
        #expect(model.focus.reticle == nil)
        model.viewfinderPressEnded()
        await settleQueuedWork()
        #expect(service.calls(after: callCount).isEmpty)
    }

    @Test("A long press over a camera that does not run locks nothing")
    func pressOverStoppedCamera() async {
        service.startError = .cannotUseCamera("Busy")
        let model = makeCaptureModel(service: service, clock: clock)
        await model.start()
        let callCount = service.calls.count
        model.viewfinderPressBegan(atUnitPoint: point, devicePoint: devicePoint)
        model.viewfinderPressEnded()
        await settleQueuedWork()
        #expect(model.focus.lock == nil)
        #expect(model.focus.reticle == nil)
        #expect(service.calls(after: callCount).isEmpty)
    }
}
