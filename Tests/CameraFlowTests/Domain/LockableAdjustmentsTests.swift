//
//  LockableAdjustmentsTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// What AE/AF Lock holds on a camera that can lock the focus, the exposure, both or neither at a point.
@Suite("What AE/AF Lock holds")
struct LockableAdjustmentsTests {

    @Test(
        "A camera locks what it can lock at a point, and nothing holds on one that can lock neither",
        arguments: [
            (true, true, LockableAdjustments?.some(.focusAndExposure)),
            (false, true, .exposure),
            (true, false, .focus),
            (false, false, nil)
        ]
    )
    func fromWhatTheCameraLocks(locksFocus: Bool, locksExposure: Bool, adjustments: LockableAdjustments?) {
        #expect(LockableAdjustments(locksFocus: locksFocus, locksExposure: locksExposure) == adjustments)
    }

    @Test("Each case says what it locks, as the camera that has it can", arguments: LockableAdjustments.allCases)
    func whatItLocks(adjustments: LockableAdjustments) {
        let locksFocus = adjustments.locksFocus
        let locksExposure = adjustments.locksExposure
        #expect(LockableAdjustments(locksFocus: locksFocus, locksExposure: locksExposure) == adjustments)
    }
}
