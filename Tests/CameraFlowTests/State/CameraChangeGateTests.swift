//
//  CameraChangeGateTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@MainActor
@Suite("One change of the camera at a time", .timeLimit(.minutes(1)))
struct CameraChangeGateTests {
    /// What the changes did, in the order they did it.
    @MainActor
    final class Record {
        var changes: [Int] = []
        var arrivals: [Int] = []
        var release: CheckedContinuation<Void, Never>?
    }

    @Test("Changes asked for while one runs wait for it, then run one at a time in the order asked")
    func order() async {
        let gate = CameraChangeGate()
        let record = Record()
        let first = Task {
            await gate.run {
                record.changes.append(1)
                await withCheckedContinuation { record.release = $0 }
            }
        }
        await settle { record.release != nil }
        var waiting: [Task<Void, Never>] = []
        for number in 2...4 {
            waiting.append(Task {
                record.arrivals.append(number)
                await gate.run { record.changes.append(number) }
            })
            await settle { record.arrivals.last == number }
        }
        await settleQueuedWork()
        #expect(record.changes == [1])
        #expect(gate.isChanging)
        record.release?.resume()
        await first.value
        for task in waiting {
            await task.value
        }
        #expect(record.changes == [1, 2, 3, 4])
        #expect(gate.isChanging == false)
    }

    @Test("A change asked for while none runs runs at once")
    func idle() async {
        let gate = CameraChangeGate()
        let record = Record()
        await gate.run { record.changes.append(1) }
        await gate.run { record.changes.append(2) }
        #expect(record.changes == [1, 2])
        #expect(gate.isChanging == false)
    }
}
