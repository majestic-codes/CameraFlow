//
//  CaptureFocusLockWaitTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import os
import Testing
@testable import CameraFlow

/// The device camera's lock of the focus and the exposure while it settles: one at a time, each ended exactly once,
/// and the observations of its camera released with it. The camera itself is a stand-in object.
@Suite("Device focus lock while the camera settles")
struct CaptureFocusLockWaitTests {
    /// What the locks of a test ended with, in order.
    private final class Outcomes: Sendable {
        private let results = OSAllocatedUnfairLock(initialState: [Bool]())

        var all: [Bool] {
            results.withLock { $0 }
        }

        func add(_ isLocked: Bool) {
            results.withLock { $0.append(isLocked) }
        }
    }

    /// A camera and an observation of it, both only identities here.
    private final class Stand {}

    private let wait = CaptureFocusLockWait()
    private let outcomes = Outcomes()
    private let camera = Stand()

    /// What a camera reads: idle, or busy with one of the four things that keep it from settling.
    enum CameraActivity: CaseIterable, Sendable {
        case idle
        case adjustingFocus
        case adjustingExposure
        case focusingOnce
        case exposingOnce
    }

    @Test(
        "A camera has settled once nothing adjusts and the one-time focus and exposure have ended",
        arguments: CameraActivity.allCases
    )
    func settling(activity: CameraActivity) {
        let hasSettled = CaptureFocusLockWait.hasSettled(
            isAdjustingFocus: activity == .adjustingFocus,
            isAdjustingExposure: activity == .adjustingExposure,
            isFocusingOnce: activity == .focusingOnce,
            isExposingOnce: activity == .exposingOnce
        )
        #expect(hasSettled == (activity == .idle))
    }

    @Test("A lock ends once, as locked, and an end after it changes nothing")
    func lockedOnce() {
        wait.begin(camera: ObjectIdentifier(camera), watch: [], completion: outcomes.add)
        #expect(wait.isWaiting(for: ObjectIdentifier(camera)))
        wait.end(isLocked: true)
        wait.end(isLocked: false)
        #expect(outcomes.all == [true])
        #expect(wait.isWaiting(for: ObjectIdentifier(camera)) == false)
    }

    @Test("A new lock gives up the one that still waits, and waits for its own camera only")
    func newLockGivesUpTheWaitingOne() {
        let other = Stand()
        wait.begin(camera: ObjectIdentifier(camera), watch: [], completion: outcomes.add)
        wait.begin(camera: ObjectIdentifier(other), watch: [], completion: outcomes.add)
        #expect(outcomes.all == [false])
        #expect(wait.isWaiting(for: ObjectIdentifier(camera)) == false)
        #expect(wait.isWaiting(for: ObjectIdentifier(other)))
        wait.end(isLocked: true)
        #expect(outcomes.all == [false, true])
    }

    @Test("An end without a lock reports nothing")
    func endWithoutLock() {
        wait.end(isLocked: false)
        #expect(outcomes.all.isEmpty)
    }

    @Test("The observations of the camera go when the lock ends")
    func observationsReleased() {
        weak var released: Stand?
        do {
            let observation = Stand()
            released = observation
            wait.begin(camera: ObjectIdentifier(camera), watch: [observation], completion: outcomes.add)
        }
        #expect(released != nil)
        wait.end(isLocked: false)
        #expect(released == nil)
    }
}
