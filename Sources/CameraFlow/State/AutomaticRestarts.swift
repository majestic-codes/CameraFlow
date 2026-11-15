//
//  AutomaticRestarts.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// How often the camera may be started again after a recoverable error without the user asking: a session that
/// keeps stopping is not restarted forever. The restarts count in a row, and a camera that ran for
/// `recoveryInterval` after one starts a new row.
///
/// The time a restarted camera ran is read from the clock when it matters: at the next error and when the camera
/// stops.
@MainActor
final class AutomaticRestarts {
    /// After this many restarts in a row the failure is shown.
    static let limit = 3
    /// How long a restarted camera runs without an error before it counts as recovered.
    static let recoveryInterval = Duration.seconds(10)

    /// Starts a stopwatch on the clock: the closure it returns tells the time since.
    private let startStopwatch: () -> () -> Duration
    private var count = 0
    /// The time the restarted camera has run, nil while no restarted camera runs.
    private var sinceRestart: (() -> Duration)?

    init(clock: some Clock<Duration>) {
        startStopwatch = {
            let start = clock.now
            return { start.duration(to: clock.now) }
        }
    }

    /// Takes one restart of the row and returns whether there was one left.
    func take() -> Bool {
        endRun()
        guard count < Self.limit else { return false }
        count += 1
        return true
    }

    /// The user started the camera: a new row begins.
    func reset() {
        sinceRestart = nil
        count = 0
    }

    /// A restarted camera runs: a new row begins once it has run for `recoveryInterval`.
    func cameraRestarted() {
        sinceRestart = startStopwatch()
    }

    /// The camera stopped: the time it ran counts no further.
    func cameraStopped() {
        endRun()
    }

    /// Ends the run of a restarted camera, which begins a new row when it lasted `recoveryInterval`.
    private func endRun() {
        if let sinceRestart, sinceRestart() >= Self.recoveryInterval {
            count = 0
        }
        sinceRestart = nil
    }
}
