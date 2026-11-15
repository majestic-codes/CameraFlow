//
//  FakeStorageSpace.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import os
@testable import CameraFlow

/// A volume with the room a test gives it, plenty unless the test says otherwise. It counts its readings, and with a
/// gate it answers only once the gate has opened.
final class FakeStorageSpace: StorageSpace {
    /// What a reading gives: a number of bytes, or no answer from the volume.
    enum Room: Sendable {
        case bytes(Int64)
        case unknown
    }

    struct Unknown: Error {}

    /// A gigabyte, far more than a photo needs.
    static let plenty: Int64 = 1_000_000_000

    private let state: OSAllocatedUnfairLock<(room: Room, readCount: Int)>
    private let gate: CallGate?

    init(room: Room = .bytes(plenty), gate: CallGate? = nil) {
        state = OSAllocatedUnfairLock(initialState: (room: room, readCount: 0))
        self.gate = gate
    }

    /// How many times the room was read.
    var readCount: Int {
        state.withLock(\.readCount)
    }

    func availableBytes() async throws -> Int64 {
        let room = state.withLock { state in
            state.readCount += 1
            return state.room
        }
        await gate?.pass()
        switch room {
        case let .bytes(bytes): return bytes
        case .unknown: throw Unknown()
        }
    }
}
