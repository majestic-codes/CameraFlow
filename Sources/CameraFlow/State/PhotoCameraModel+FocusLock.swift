//
//  PhotoCameraModel+FocusLock.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

// MARK: - AE/AF Lock

extension PhotoCameraModel {

    /// A long press began on the viewfinder. It closes the control panel when it is open, as a tap does, and over a
    /// camera that runs it starts the lock at the point, of what the camera can lock: a camera that can lock nothing
    /// offers no lock. Like the stock one, it plays no haptic.
    func viewfinderPressBegan(atUnitPoint unitPoint: CGPoint, devicePoint: CGPoint) {
        guard !panel.isOpen else {
            panel.dismiss()
            return
        }
        guard session.isRunning else { return }
        focus.beginLockPress(atUnitPoint: unitPoint, devicePoint: devicePoint)
    }

    /// The finger of a long press let go of the viewfinder. A lock that has not held long enough is given up.
    func viewfinderPressEnded() {
        focus.endLockPress()
    }

    /// VoiceOver's action on the viewfinder: it ends a lock, or locks at the reticle, or at the middle of the picture
    /// where none is shown, over a camera that runs. A camera that can lock nothing offers no lock, and the viewfinder
    /// then has no such action.
    func toggleFocusLock() {
        guard focus.lock == nil else {
            focus.unlock()
            return
        }
        guard session.isRunning else { return }
        focus.lockAtReticle()
    }
}
