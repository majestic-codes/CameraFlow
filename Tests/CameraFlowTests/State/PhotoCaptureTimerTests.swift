//
//  PhotoCaptureTimerTests.swift
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
@Suite("Self-timer", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoCaptureTimerTests {
    // MARK: - Timer

    @Test(
        "The timer counts down from its value and fires at zero",
        arguments: [CameraFlowTimer.threeSeconds, .fiveSeconds, .tenSeconds]
    )
    func timer(timer: CameraFlowTimer) async throws {
        let service = RecordingCameraService()
        let clock = ManualClock()
        var state = CameraFlowInitialState()
        state.timer.value = timer
        let model = makeCaptureModel(service: service, initialState: state, clock: clock)
        await model.start()
        var seen: [Int] = []
        let shutter = Task { await model.capture() }
        for _ in 1...timer.rawValue {
            await clock.waitForSleepers()
            seen.append(try #require(model.shutter.countdownSeconds))
            clock.advance(by: .seconds(1))
        }
        await shutter.value
        #expect(seen == Array((1...timer.rawValue).reversed()))
        #expect(model.shutter.countdownSeconds == nil)
        #expect(model.shutter.isCountingDown == false)
        #expect(model.shutter.captureCount == 1)
        #expect(service.captureRequests.count == 1)
    }

    @Test("A countdown is cancelled by cancelCountdown or by a second shutter tap", arguments: [false, true])
    func cancelTimer(bySecondTap: Bool) async throws {
        let service = RecordingCameraService()
        let clock = ManualClock()
        var state = CameraFlowInitialState()
        state.timer.value = .tenSeconds
        let model = makeCaptureModel(service: service, initialState: state, clock: clock)
        await model.start()
        let shutter = Task { await model.capture() }
        await clock.waitForSleepers()
        #expect(model.shutter.isCountingDown)
        #expect(model.shutter.countdownSeconds == 10)
        if bySecondTap {
            await model.capture()
        } else {
            model.shutter.cancelCountdown()
        }
        await shutter.value
        #expect(service.captureRequests.isEmpty)
        #expect(model.shutter.captureCount == 0)
        #expect(model.shutter.countdownSeconds == nil)
    }

    @Test("An interruption cancels a running countdown")
    func interruptionCancelsTimer() async throws {
        let service = RecordingCameraService()
        let clock = ManualClock()
        var state = CameraFlowInitialState()
        state.timer.value = .threeSeconds
        let model = makeCaptureModel(service: service, initialState: state, clock: clock)
        await model.start()
        let shutter = Task { await model.capture() }
        await clock.waitForSleepers()
        await service.simulate(.interrupted(.audioInUseByAnotherClient))
        await shutter.value
        #expect(service.captureRequests.isEmpty)
    }

    @Test("Stopping the camera cancels a running countdown")
    func stopCancelsTimer() async throws {
        let service = RecordingCameraService()
        let clock = ManualClock()
        var state = CameraFlowInitialState()
        state.timer.value = .threeSeconds
        let model = makeCaptureModel(service: service, initialState: state, clock: clock)
        await model.start()
        let shutter = Task { await model.capture() }
        await clock.waitForSleepers()
        model.stop()
        await shutter.value
        #expect(service.captureRequests.isEmpty)
        #expect(model.shutter.countdownSeconds == nil)
    }
}
