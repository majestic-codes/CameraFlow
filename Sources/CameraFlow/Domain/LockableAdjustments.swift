//
//  LockableAdjustments.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What AE/AF Lock holds on a camera: the focus and the exposure at a point, or the one of the two the camera can
/// lock there. A camera with a fixed focus locks the exposure alone, which the stock badge calls AE LOCK.
enum LockableAdjustments: Sendable, Equatable, CaseIterable {
    case focusAndExposure
    /// The exposure alone (AE): the camera cannot focus at a point and lock its focus there.
    case exposure
    /// The focus alone (AF): the camera cannot expose at a point and lock its exposure there.
    case focus

    /// What a camera that can lock the focus, the exposure or both holds, nil for one that can lock neither.
    init?(locksFocus: Bool, locksExposure: Bool) {
        switch (locksFocus, locksExposure) {
        case (true, true): self = .focusAndExposure
        case (false, true): self = .exposure
        case (true, false): self = .focus
        case (false, false): return nil
        }
    }

    var locksFocus: Bool {
        self != .exposure
    }

    var locksExposure: Bool {
        self != .focus
    }
}
