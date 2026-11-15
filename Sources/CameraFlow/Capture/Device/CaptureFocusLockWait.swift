//
//  CaptureFocusLockWait.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The lock of the focus and the exposure while the camera in the viewfinder settles into it. One lock waits at a
/// time, and each ends exactly once: locked when the camera has settled, or not when a new lock, a focus, a reset,
/// an unlock, a start or a stop gives it up first. Used on the session queue only.
final class CaptureFocusLockWait {
    typealias Completion = @Sendable (Bool) -> Void

    /// The camera the lock waits for, nil while none waits.
    private var camera: ObjectIdentifier?
    /// What brings the adjustments of that camera to the wait, released when the wait ends.
    private var watch: [AnyObject] = []
    private var completion: Completion?

    /// Whether a camera has settled after it was asked to focus and expose once at a point: nothing adjusts any
    /// more, and the one-time focus and exposure have ended, which the camera marks by locking each itself.
    static func hasSettled(
        isAdjustingFocus: Bool,
        isAdjustingExposure: Bool,
        isFocusingOnce: Bool,
        isExposingOnce: Bool
    ) -> Bool {
        !isAdjustingFocus && !isAdjustingExposure && !isFocusingOnce && !isExposingOnce
    }

    /// Waits for a camera to settle into a lock, with what brings its adjustments here. A lock that still waits is
    /// given up first.
    func begin(camera: ObjectIdentifier, watch: [AnyObject], completion: @escaping Completion) {
        end(isLocked: false)
        self.camera = camera
        self.watch = watch
        self.completion = completion
    }

    /// Whether the lock waits for this camera.
    func isWaiting(for camera: ObjectIdentifier) -> Bool {
        self.camera == camera
    }

    /// Ends the lock that waits, as locked or as given up, and stops watching its camera. Without one it does
    /// nothing, so a lock never ends twice.
    func end(isLocked: Bool) {
        let completion = self.completion
        camera = nil
        watch = []
        self.completion = nil
        completion?(isLocked)
    }
}
