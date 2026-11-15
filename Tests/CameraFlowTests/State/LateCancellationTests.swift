//
//  LateCancellationTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

/// A timer cancelled after its sleep ended, before the main actor ran what comes after it: the clock has woken the
/// timer, and the test cancels it before it yields.
@MainActor
@Suite("A timer cancelled as it ends", .temporaryDirectory, .timeLimit(.minutes(1)))
struct LateCancellationTests {

    @Test("A countdown cancelled as its last second ends returns without its photo")
    func countdown() async {
        let clock = ManualClock()
        let countdown = PhotoCaptureCountdown(clock: clock)
        let run = Task { await countdown.run(seconds: 1) }
        await clock.waitForSleepers()
        clock.advance(by: .seconds(1))
        countdown.cancel()
        #expect(await run.value == false)
    }

    @Test("A shot whose countdown is cancelled as it ends takes no photo")
    func shotCancelledAsCountdownEnds() async {
        let service = RecordingCameraService()
        let clock = ManualClock()
        var state = CameraFlowInitialState()
        state.timer.value = .threeSeconds
        let model = makeCaptureModel(service: service, initialState: state, clock: clock)
        await model.start()
        let shutter = Task { await model.capture() }
        for _ in 1..<CameraFlowTimer.threeSeconds.rawValue {
            await clock.waitForSleepers()
            clock.advance(by: .seconds(1))
        }
        await clock.waitForSleepers()
        clock.advance(by: .seconds(1))
        model.shutter.cancelCountdown()
        await shutter.value
        #expect(model.shutter.captureCount == 0)
        #expect(service.captureRequests.isEmpty)
    }

    @Test("A drag that begins as the reticle's lifetime ends keeps the reticle")
    func reticleHeldAsItsLifetimeEnds() async {
        let clock = ManualClock()
        let focus = FocusModel(service: RecordingCameraService(), clock: clock)
        let point = CGPoint(x: 0.25, y: 0.75)
        focus.focus(atUnitPoint: point, devicePoint: point)
        await clock.waitForSleepers()
        clock.advance(by: FocusModel.reticleLifetime)
        focus.beginAdjustingExposure()
        await settleQueuedWork()
        #expect(focus.reticle?.location == point)
        #expect(focus.isAdjustingExposure)
    }

    /// The watch reads the clock when the camera stops, so a camera that stops a moment before its interval ends
    /// has not recovered, however long the clock runs on.
    @Test("A recovery watch cancelled as its interval ends keeps counting the restarts")
    func recoveryWatchCancelledAsItEnds() {
        let clock = ManualClock()
        let restarts = AutomaticRestarts(clock: clock)
        let taken = (1...AutomaticRestarts.limit).map { _ in restarts.take() }
        #expect(taken == Array(repeating: true, count: AutomaticRestarts.limit))
        restarts.cameraRestarted()
        clock.advance(by: AutomaticRestarts.recoveryInterval - .milliseconds(1))
        restarts.cameraStopped()
        clock.advance(by: .milliseconds(1))
        #expect(restarts.take() == false)
    }
}
