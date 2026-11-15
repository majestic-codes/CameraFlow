//
//  PhotoCaptureCountdown.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation

/// The self-timer: counts whole seconds down to zero, and can be cancelled while it runs.
@MainActor
@Observable
final class PhotoCaptureCountdown {
    /// Seconds left, shown from the full value down to 1. Nil while no countdown runs.
    private(set) var remainingSeconds: Int?

    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private var task: Task<Bool, Never>?

    private static let step = Duration.seconds(1)

    init(clock: any Clock<Duration>) {
        self.clock = clock
    }

    var isRunning: Bool {
        task != nil
    }

    /// Counts down and returns true at zero, or false when it was cancelled.
    func run(seconds: Int) async -> Bool {
        remainingSeconds = seconds
        let countdown = Task { [clock] () -> Bool in
            for remaining in stride(from: seconds, to: 0, by: -1) {
                remainingSeconds = remaining
                do {
                    try await clock.sleep(for: Self.step)
                    // A cancel that comes after the last second ended still takes no photo.
                    try Task.checkCancellation()
                } catch {
                    return false
                }
            }
            return true
        }
        task = countdown
        let isFinished = await countdown.value
        task = nil
        remainingSeconds = nil
        return isFinished
    }

    func cancel() {
        task?.cancel()
    }
}
