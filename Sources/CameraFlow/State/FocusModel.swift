//
//  FocusModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Observation

/// Focus at a tapped point, the reticle that marks it, and the stock AE/AF Lock that a long press sets: the focus and
/// the exposure, or the one of the two the running camera can lock, held at a point until a tap elsewhere, a change of
/// the lens or of the camera, or the camera stopping. A camera that can lock neither offers no lock.
@MainActor
@Observable
final class FocusModel {
    private(set) var reticle: FocusReticle?
    /// Whether a finger is changing the exposure. The reticle stays while it is.
    private(set) var isAdjustingExposure = false
    /// The lock of the focus and the exposure, nil without one. The reticle stays while there is one.
    private(set) var lock: FocusLock?
    /// Whether the finger of a long press still holds the viewfinder. The reticle stays while it does.
    private(set) var isPressing = false
    /// What the running camera can lock at a point, which the words of the lock follow. Nil before a camera has
    /// started and on one that can lock neither the focus nor the exposure, where nothing locks.
    private(set) var lockableAdjustments: LockableAdjustments?

    @ObservationIgnored private let service: any CameraService
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private var reticleTask: Task<Void, Never>?
    @ObservationIgnored private var reticleCount = 0
    /// The wait of the lock under way for the camera to settle, and for its press to hold long enough.
    @ObservationIgnored private var lockTasks: [Task<Void, Never>] = []
    /// Whether the camera has settled into the lock under way.
    @ObservationIgnored private var hasCameraLocked = false

    /// How long the reticle stays: about 4.05 s at full brightness, then dimmed. The stock dimmed phase was not
    /// measured, so 8 s in all is an estimate.
    static let reticleLifetime = Duration.seconds(8)
    /// How long a long press holds before its lock takes: the stock camera locks one second after the press began.
    static let lockDelay = Duration.seconds(1)
    /// The middle of the picture, where VoiceOver locks without a reticle, in the viewfinder's unit coordinates and
    /// in the camera's alike.
    private static let pictureCenter = CGPoint(x: 0.5, y: 0.5)

    init(service: any CameraService, clock: any Clock<Duration>) {
        self.service = service
        self.clock = clock
    }

    /// Focuses at a point of the viewfinder and shows the reticle there for its lifetime, which ends a lock. The
    /// point comes in unit coordinates of the viewfinder, for the reticle, and in the camera's coordinates, for the
    /// focus.
    func focus(atUnitPoint unitPoint: CGPoint, devicePoint: CGPoint) {
        endLock()
        isPressing = false
        service.focus(atDevicePoint: devicePoint)
        let shown = makeReticle(at: unitPoint, devicePoint: devicePoint, kind: .tap)
        reticle = shown
        isAdjustingExposure = false
        scheduleRemoval(of: shown)
    }

    // MARK: - The lock

    /// Takes what the camera that has just started can lock at a point.
    func cameraStarted(lockableAdjustments: LockableAdjustments?) {
        self.lockableAdjustments = lockableAdjustments
    }

    /// A long press began at a point of the viewfinder: the camera focuses and exposes there, and the reticle marks
    /// the point while the finger holds. The lock takes once the press has held for `lockDelay` and the camera has
    /// settled. A camera that can lock nothing takes no press.
    func beginLockPress(atUnitPoint unitPoint: CGPoint, devicePoint: CGPoint) {
        guard lockableAdjustments != nil else { return }
        startLock(at: makeReticle(at: unitPoint, devicePoint: devicePoint, kind: .press), phase: .pressing)
        isPressing = true
    }

    /// The finger of a long press let go. A lock that has not held long enough is given up: the camera watches its
    /// picture again and the reticle stays for its lifetime, as after a tap.
    func endLockPress() {
        guard isPressing else { return }
        isPressing = false
        if lock == .pressing {
            endLock()
            service.unlockFocusAndExposure()
        }
        if let reticle {
            scheduleRemoval(of: reticle)
        }
    }

    /// Locks the focus and the exposure without a press, as VoiceOver asks: at the reticle, or at the middle of the
    /// picture where none is shown. The lock takes once the camera has settled. A camera that can lock nothing does
    /// not lock.
    func lockAtReticle() {
        guard lockableAdjustments != nil else { return }
        let shown = reticle ?? makeReticle(at: Self.pictureCenter, devicePoint: Self.pictureCenter, kind: .tap)
        startLock(at: shown, phase: .settling)
    }

    /// Ends a lock, whether it holds or still settles: the camera focuses and exposes by itself again, and the
    /// reticle goes. Without a lock nothing happens.
    func unlock() {
        guard lock != nil else { return }
        service.resetFocus()
        clear()
    }

    // MARK: - Exposure under the reticle

    /// Holds the reticle while a finger changes the exposure. Does nothing when no reticle is shown.
    func beginAdjustingExposure() {
        guard reticle != nil else { return }
        isAdjustingExposure = true
        reticleTask?.cancel()
    }

    /// Lets the reticle stay for its lifetime again, counted from now, unless a lock holds it.
    func endAdjustingExposure() {
        guard isAdjustingExposure else { return }
        isAdjustingExposure = false
        if let reticle {
            scheduleRemoval(of: reticle)
        }
    }

    /// The exposure changed without a finger on the viewfinder, by the adjustable element of the reticle: the
    /// reticle stays for its lifetime again, counted from now, so the element does not go while it is used.
    func exposureAdjusted() {
        guard !isAdjustingExposure, let reticle else { return }
        scheduleRemoval(of: reticle)
    }

    /// Takes the reticle away and ends a lock, as the camera stops or changes.
    func clear() {
        endLock()
        isPressing = false
        reticleTask?.cancel()
        reticle = nil
        isAdjustingExposure = false
    }

    /// The camera's picture changed a lot since it focused at a point: it focuses and exposes by itself again, and
    /// the reticle goes. A finger that changes the exposure keeps both, and so does a lock.
    func subjectAreaChanged() {
        guard !isAdjustingExposure, lock == nil else { return }
        service.resetFocus()
        clear()
    }

    // MARK: - Private

    /// Shows the reticle of a lock and starts it: the camera focuses and exposes at the reticle's point and settles
    /// into the lock, and a press also waits for `lockDelay`.
    private func startLock(at shown: FocusReticle, phase: FocusLock) {
        endLock()
        reticleTask?.cancel()
        reticle = shown
        isAdjustingExposure = false
        lock = phase
        let devicePoint = shown.devicePoint
        let cameraLock = Task { [weak self, service] in
            // A lock that ended before the task ran is not asked for, so it never follows the call that ended it.
            guard !Task.isCancelled else { return }
            let isLocked = await service.lockFocusAndExposure(atDevicePoint: devicePoint)
            guard !Task.isCancelled else { return }
            self?.cameraSettled(isLocked: isLocked)
        }
        lockTasks = [cameraLock]
        guard phase == .pressing else { return }
        let press = Task { [weak self, clock] in
            do {
                try await clock.sleep(for: Self.lockDelay)
                // A cancel that comes after the sleep ended still gives the press up.
                try Task.checkCancellation()
            } catch {
                return
            }
            self?.pressHeld()
        }
        lockTasks.append(press)
    }

    /// The press held long enough: the lock takes now where the camera has settled, and once it settles otherwise.
    private func pressHeld() {
        guard lock == .pressing else { return }
        lock = hasCameraLocked ? .locked : .settling
    }

    /// The camera answered the lock under way. A camera that settled into it holds it, and the lock takes unless its
    /// press has not held long enough yet. A camera that gave it up ends it, and the reticle stays for its lifetime
    /// once no finger holds it.
    private func cameraSettled(isLocked: Bool) {
        guard isLocked else {
            endLock()
            if let reticle {
                scheduleRemoval(of: reticle)
            }
            return
        }
        hasCameraLocked = true
        if lock == .settling {
            lock = .locked
        }
    }

    /// Ends the lock under way and its waits.
    private func endLock() {
        lockTasks.forEach { $0.cancel() }
        lockTasks = []
        lock = nil
        hasCameraLocked = false
    }

    /// Takes the reticle away after its lifetime, counted from now. A reticle that a lock or a press holds stays.
    private func scheduleRemoval(of shown: FocusReticle) {
        reticleTask?.cancel()
        guard lock == nil, !isPressing else { return }
        reticleTask = Task { [weak self, clock] in
            do {
                try await clock.sleep(for: Self.reticleLifetime)
                // A cancel that comes after the sleep ended still keeps the reticle.
                try Task.checkCancellation()
            } catch {
                return
            }
            if let self, reticle == shown {
                reticle = nil
            }
        }
    }

    private func makeReticle(at unitPoint: CGPoint, devicePoint: CGPoint, kind: FocusReticle.Kind) -> FocusReticle {
        reticleCount += 1
        return FocusReticle(identifier: reticleCount, location: unitPoint, devicePoint: devicePoint, kind: kind)
    }
}
