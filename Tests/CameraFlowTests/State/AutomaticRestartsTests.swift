//
//  AutomaticRestartsTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@MainActor
@Suite("The restarts of a camera that keeps stopping")
struct AutomaticRestartsTests {
    let clock = ManualClock()

    /// Takes the restarts of a row, each followed by a camera that runs for `run`.
    private func restart(_ restarts: AutomaticRestarts, times: Int, running run: Duration) -> [Bool] {
        (0..<times).map { _ in
            let isTaken = restarts.take()
            restarts.cameraRestarted()
            clock.advance(by: run)
            return isTaken
        }
    }

    @Test("Three restarts in a row are taken, and the fourth is refused")
    func limit() {
        let restarts = AutomaticRestarts(clock: clock)
        let taken = restart(restarts, times: 4, running: .seconds(1))
        #expect(taken == [true, true, true, false])
    }

    @Test("A restarted camera that ran for the recovery interval begins a new row")
    func recovered() {
        let restarts = AutomaticRestarts(clock: clock)
        #expect(restart(restarts, times: 3, running: .seconds(1)) == [true, true, true])
        clock.advance(by: AutomaticRestarts.recoveryInterval)
        #expect(restart(restarts, times: 4, running: .zero) == [true, true, true, false])
    }

    @Test("A restarted camera that stops again just before the recovery interval keeps counting")
    func notYetRecovered() {
        let restarts = AutomaticRestarts(clock: clock)
        let run = AutomaticRestarts.recoveryInterval - .seconds(1)
        #expect(restart(restarts, times: 4, running: run) == [true, true, true, false])
    }

    @Test("A camera stopped after it ran for the recovery interval has begun a new row")
    func stoppedAfterRecovery() {
        let restarts = AutomaticRestarts(clock: clock)
        #expect(restart(restarts, times: 3, running: .seconds(1)) == [true, true, true])
        clock.advance(by: AutomaticRestarts.recoveryInterval)
        restarts.cameraStopped()
        #expect(restart(restarts, times: 4, running: .zero) == [true, true, true, false])
    }

    @Test("A camera stopped before the recovery interval stops counting the time it runs")
    func stoppedBeforeRecovery() {
        let restarts = AutomaticRestarts(clock: clock)
        #expect(restart(restarts, times: 3, running: .seconds(1)) == [true, true, true])
        restarts.cameraStopped()
        clock.advance(by: AutomaticRestarts.recoveryInterval)
        #expect(restarts.take() == false)
    }

    @Test("A reset begins a new row at once")
    func reset() {
        let restarts = AutomaticRestarts(clock: clock)
        #expect(restart(restarts, times: 4, running: .zero) == [true, true, true, false])
        restarts.reset()
        #expect(restart(restarts, times: 4, running: .zero) == [true, true, true, false])
    }
}
