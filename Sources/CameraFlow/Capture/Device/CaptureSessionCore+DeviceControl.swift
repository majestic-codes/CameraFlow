//
//  CaptureSessionCore+DeviceControl.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation

// MARK: - Zoom, focus and exposure of the camera in the viewfinder

extension CaptureSessionCore {

    func setZoom(_ factor: CGFloat, rampRate: Float?) {
        queue.async {
            guard let device = self.controlledDevice else { return }
            let deviceFactor = factor / self.displayMultiplier
            CaptureDeviceControl.setZoom(deviceFactor, rampRate: rampRate, on: device)
        }
    }

    func focus(at devicePoint: CGPoint) {
        queue.async {
            self.focusLockWait.end(isLocked: false)
            guard let device = self.controlledDevice else { return }
            CaptureDeviceControl.focus(at: devicePoint, on: device, watchesSubjectArea: true)
        }
    }

    func resetFocus() {
        queue.async {
            self.focusLockWait.end(isLocked: false)
            guard let device = self.controlledDevice else { return }
            CaptureDeviceControl.resetFocus(on: device)
        }
    }

    func setExposureBias(_ bias: Float) {
        queue.async {
            guard let device = self.controlledDevice else { return }
            CaptureDeviceControl.setExposureBias(bias, on: device)
        }
    }
}

// MARK: - The lock of the focus and the exposure

extension CaptureSessionCore {

    /// Focuses and exposes once at a point without watching the picture, and locks both once the camera has
    /// settled, which the key-value observation of its adjustments tells on the queue. The completion gets whether
    /// the lock holds, false when it was given up first or no camera runs. The work is queued at the call, in the
    /// order of the calls around it.
    func lockFocusAndExposure(at devicePoint: CGPoint, completion: @escaping CaptureFocusLockWait.Completion) {
        queue.async {
            guard let device = self.controlledDevice else {
                self.focusLockWait.end(isLocked: false)
                completion(false)
                return
            }
            CaptureDeviceControl.focus(at: devicePoint, on: device, watchesSubjectArea: false)
            let watch = self.makeAdjustmentObservations(of: device)
            self.focusLockWait.begin(camera: ObjectIdentifier(device), watch: watch, completion: completion)
        }
    }

    /// Gives up a lock, whether it holds or still settles, and watches the picture again as after a tap.
    func unlockFocusAndExposure() {
        queue.async {
            self.focusLockWait.end(isLocked: false)
            guard let device = self.controlledDevice else { return }
            CaptureDeviceControl.watchSubjectArea(of: device)
        }
    }

    /// Observations that bring every change of the focus and the exposure of a camera to the queue, the values it
    /// has now included.
    private func makeAdjustmentObservations(of device: AVCaptureDevice) -> [AnyObject] {
        let identifier = ObjectIdentifier(device)
        let adjusted: @Sendable () -> Void = { [weak self] in
            guard let self else { return }
            queue.async { self.cameraAdjusted(identifier) }
        }
        let options: NSKeyValueObservingOptions = [.initial, .new]
        return [
            device.observe(\.isAdjustingFocus, options: options) { _, _ in adjusted() },
            device.observe(\.isAdjustingExposure, options: options) { _, _ in adjusted() },
            device.observe(\.focusMode, options: options) { _, _ in adjusted() },
            device.observe(\.exposureMode, options: options) { _, _ in adjusted() }
        ]
    }

    /// Locks the camera in the viewfinder once it has settled into the lock that waits for it. A change that a camera
    /// reported after its lock ended, or after it left the viewfinder, is dropped.
    private func cameraAdjusted(_ identifier: ObjectIdentifier) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let device = controlledDevice,
              ObjectIdentifier(device) == identifier,
              focusLockWait.isWaiting(for: identifier),
              CaptureDeviceControl.hasSettled(device) else { return }
        CaptureDeviceControl.lockFocusAndExposure(of: device)
        focusLockWait.end(isLocked: true)
    }
}
#endif
