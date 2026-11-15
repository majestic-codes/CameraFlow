//
//  DialHapticSchedule.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// When the zoom dial's tick plays and when its haptic engine starts.
///
/// A tick plays at most once in 10 milliseconds of the monotonic clock, so a change of the wall clock never holds
/// ticks back. The engine starts without blocking: at the beginning, and again at the first tick after the system
/// stopped or reset it, which plays once the engine runs.
struct DialHapticSchedule {
    /// What the player does with a tick.
    enum Step: Equatable {
        /// Plays the tick on the running engine.
        case play
        /// Starts the engine, and plays the tick once it runs.
        case startEngine
        /// Lets the tick go: it comes too soon after the last one, or while a tick waits for the engine.
        case skip
    }

    private enum Engine: Equatable {
        case stopped
        /// Being started, with a tick that plays once it runs or without one.
        case starting(hasTick: Bool)
        case running
    }

    /// The shortest time between two ticks.
    static let minimumInterval = Duration.milliseconds(10)
    private var engine = Engine.stopped
    private var lastTick: ContinuousClock.Instant?

    /// The engine is being started without a tick, at the beginning.
    mutating func engineStarting() {
        engine = .starting(hasTick: false)
    }

    /// What the player does with a tick at `instant`.
    mutating func tick(at instant: ContinuousClock.Instant) -> Step {
        if let lastTick, lastTick.duration(to: instant) < Self.minimumInterval {
            return .skip
        }
        lastTick = instant
        switch engine {
        case .running:
            return .play
        case .starting:
            engine = .starting(hasTick: true)
            return .skip
        case .stopped:
            engine = .starting(hasTick: true)
            return .startEngine
        }
    }

    /// The engine runs. Returns whether a tick waits to play.
    mutating func engineStarted() -> Bool {
        guard case let .starting(hasTick) = engine else { return false }
        engine = .running
        return hasTick
    }

    /// The engine could not start, or the system stopped or reset it: the next tick starts it again.
    mutating func engineStopped() {
        engine = .stopped
    }
}
