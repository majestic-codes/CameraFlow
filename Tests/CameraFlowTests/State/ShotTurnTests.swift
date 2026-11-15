//
//  ShotTurnTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// The turns that keep the photos of the shutter in the order they were shot.
@MainActor
@Suite("The order of the shutter's photos", .timeLimit(.minutes(1)))
struct ShotTurnTests {
    /// The turns in the order they began.
    @MainActor
    private final class Record {
        var began: [String] = []
    }

    @Test("A turn after none, and a turn after one that is over, begin at once")
    func beginsAtOnce() async {
        let first = ShotTurn(after: nil)
        await first.begin()
        first.end()
        let second = ShotTurn(after: first)
        await second.begin()
        second.end()
    }

    @Test("Each turn begins once the turn before it has ended, whatever order they were waited for in")
    func order() async {
        let record = Record()
        let first = ShotTurn(after: nil)
        let second = ShotTurn(after: first)
        let third = ShotTurn(after: second)
        let thirdTurn = Task {
            await third.begin()
            record.began.append("third")
            third.end()
        }
        let secondTurn = Task {
            await second.begin()
            record.began.append("second")
            second.end()
        }
        await settleQueuedWork()
        #expect(record.began.isEmpty)
        await first.begin()
        record.began.append("first")
        first.end()
        await secondTurn.value
        await thirdTurn.value
        #expect(record.began == ["first", "second", "third"])
    }
}
