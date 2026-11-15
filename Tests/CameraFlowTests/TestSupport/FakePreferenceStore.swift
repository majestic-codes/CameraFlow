//
//  FakePreferenceStore.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import os
@testable import CameraFlow

/// A preference store in memory, with a record of every write.
final class FakePreferenceStore: PreferenceStore, Sendable {
    private struct State {
        var values: [String: Data] = [:]
        var writeCount = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    init(values: [String: Data] = [:]) {
        state.withLock { $0.values = values }
    }

    var keys: [String] {
        state.withLock { $0.values.keys.sorted() }
    }

    var writeCount: Int {
        state.withLock(\.writeCount)
    }

    func data(forKey key: String) -> Data? {
        state.withLock { $0.values[key] }
    }

    func set(_ data: Data?, forKey key: String) {
        state.withLock { state in
            state.writeCount += 1
            state.values[key] = data
        }
    }
}

extension CaptureTestSupport {

    /// A memory of the camera settings over a fake store, under the default prefix.
    static func makeMemory(store: FakePreferenceStore = FakePreferenceStore()) -> PreferencesMemory {
        PreferencesMemory(store: store, keyPrefix: "CameraFlow.")
    }
}
