//
//  DialHapticScheduleTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("When the dial's tick plays and its haptic engine starts")
struct DialHapticScheduleTests {
    private let beginning = ContinuousClock.now

    /// What the schedule does with ticks at the milliseconds given after the beginning, one after another.
    private func ticks(
        _ schedule: inout DialHapticSchedule,
        atMilliseconds milliseconds: [Int]
    ) -> [DialHapticSchedule.Step] {
        milliseconds.map { millisecond in
            schedule.tick(at: beginning.advanced(by: .milliseconds(millisecond)))
        }
    }

    /// A schedule whose engine was started at the beginning and runs.
    private func runningSchedule() -> DialHapticSchedule {
        var schedule = DialHapticSchedule()
        schedule.engineStarting()
        let hasWaitingTick = schedule.engineStarted()
        #expect(hasWaitingTick == false)
        return schedule
    }

    @Test("An engine started at the beginning plays the first tick at once")
    func startedAtTheBeginning() {
        var schedule = runningSchedule()
        #expect(ticks(&schedule, atMilliseconds: [0]) == [.play])
    }

    @Test("Ticks closer than 10 milliseconds on the monotonic clock play once")
    func pacing() {
        var schedule = runningSchedule()
        let steps = ticks(&schedule, atMilliseconds: [0, 9, 10, 15, 25])
        #expect(steps == [.play, .skip, .play, .skip, .play])
    }

    @Test("A tick while the engine starts at the beginning plays once it runs")
    func tickWhileStarting() {
        var schedule = DialHapticSchedule()
        schedule.engineStarting()
        #expect(ticks(&schedule, atMilliseconds: [0]) == [.skip])
        let hasWaitingTick = schedule.engineStarted()
        #expect(hasWaitingTick)
        #expect(ticks(&schedule, atMilliseconds: [10]) == [.play])
    }

    @Test("An engine the system stopped or reset is started by the next tick, which plays once it runs")
    func restartedByATick() {
        var schedule = runningSchedule()
        schedule.engineStopped()
        #expect(ticks(&schedule, atMilliseconds: [0, 20]) == [.startEngine, .skip])
        let hasWaitingTick = schedule.engineStarted()
        let startsAgain = schedule.engineStarted()
        #expect(hasWaitingTick)
        #expect(startsAgain == false)
        #expect(ticks(&schedule, atMilliseconds: [40]) == [.play])
    }

    @Test("An engine that could not start, or stopped before its start came back, is started by the next tick")
    func notStarted() {
        var schedule = DialHapticSchedule()
        schedule.engineStarting()
        schedule.engineStopped()
        let hasWaitingTick = schedule.engineStarted()
        #expect(hasWaitingTick == false)
        #expect(ticks(&schedule, atMilliseconds: [0]) == [.startEngine])
    }
}
