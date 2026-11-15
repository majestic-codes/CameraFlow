//
//  DialHapticPlayer.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import CoreHaptics
import os

/// The tick of the zoom dial on a haptic engine of its own, which plays haptics only and never blocks the main actor:
/// it starts without waiting, and starts again after the system stopped or reset it (`DialHapticSchedule`).
@MainActor
final class DialHapticPlayer {
    nonisolated private static let logger = Logger.camera("DialHapticPlayer")
    /// The strength of a tick, from 0 to 1.
    private static let tickIntensity: Float = 0.333
    /// The crispness of a tick, from 0 to 1.
    private static let tickSharpness: Float = 15.0 / 23.0
    /// Nil, with `pattern`, on a device without haptics or where the engine cannot be made.
    private let engine: CHHapticEngine?
    private let pattern: CHHapticPattern?
    private var schedule = DialHapticSchedule()

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            engine = nil
            pattern = nil
            return
        }
        do {
            let engine = try CHHapticEngine()
            let pattern = try Self.makeTickPattern()
            self.engine = engine
            self.pattern = pattern
            prepare(engine)
        } catch {
            Self.logger.error("Cannot create the dial haptic: \(error.localizedDescription, privacy: .public)")
            engine = nil
            pattern = nil
        }
    }

    func tick() {
        guard let engine, let pattern else { return }
        switch schedule.tick(at: .now) {
        case .play: play(pattern, on: engine)
        case .startEngine: start(engine)
        case .skip: break
        }
    }

    /// One light transient, the tick of the stock camera's dial.
    private static func makeTickPattern() throws -> CHHapticPattern {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: tickIntensity)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: tickSharpness)
        let tick = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        return try CHHapticPattern(events: [tick], parameters: [])
    }

    /// Plays haptics without the audio of the engine, lets the engine turn the hardware off while it is idle, hears
    /// when the system stops or resets it, and starts it.
    private func prepare(_ engine: CHHapticEngine) {
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        engine.stoppedHandler = { @Sendable [weak self] reason in
            Self.logger.info("The dial haptic engine stopped: \(reason.rawValue, privacy: .public)")
            Task { @MainActor in
                self?.schedule.engineStopped()
            }
        }
        engine.resetHandler = { @Sendable [weak self] in
            Self.logger.info("The dial haptic engine was reset")
            Task { @MainActor in
                self?.schedule.engineStopped()
            }
        }
        schedule.engineStarting()
        start(engine)
    }

    /// Starts the engine without waiting for it. The callbacks of the engine come in order on a queue of its own.
    private func start(_ engine: CHHapticEngine) {
        engine.start { @Sendable [weak self] error in
            Task { @MainActor in
                self?.engineStarted(error: error)
            }
        }
    }

    private func engineStarted(error: (any Error)?) {
        if let error {
            Self.logger.error("Cannot start the dial haptic: \(error.localizedDescription, privacy: .public)")
            schedule.engineStopped()
            return
        }
        let hasWaitingTick = schedule.engineStarted()
        guard hasWaitingTick, let engine, let pattern else { return }
        play(pattern, on: engine)
    }

    /// Plays a tick now. A tick the engine cannot play leaves it to be started again by the next one.
    private func play(_ pattern: CHHapticPattern, on engine: CHHapticEngine) {
        do {
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            Self.logger.error("Cannot play the dial haptic: \(error.localizedDescription, privacy: .public)")
            schedule.engineStopped()
        }
    }
}
#endif
