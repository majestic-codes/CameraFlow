//
//  UserDefaultsPreferenceStoreTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@Suite("The flow's memory in the user defaults")
struct UserDefaultsPreferenceStoreTests {

    /// A suite of defaults of its own, removed when the test is over.
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "CameraFlowTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test("Data is kept under its key, and nil removes it")
    func setAndRemove() throws {
        try withDefaults { defaults in
            let store = UserDefaultsPreferenceStore(defaults: defaults)
            store.set(Data([1, 2, 3]), forKey: "cameraFlow.test")
            #expect(store.data(forKey: "cameraFlow.test") == Data([1, 2, 3]))
            store.set(nil, forKey: "cameraFlow.test")
            #expect(store.data(forKey: "cameraFlow.test") == nil)
            #expect(defaults.object(forKey: "cameraFlow.test") == nil)
        }
    }

    @Test("What the user chose comes back from the defaults, and a damaged value is removed from them")
    func memory() throws {
        try withDefaults { defaults in
            let memory = PreferencesMemory(store: UserDefaultsPreferenceStore(defaults: defaults), keyPrefix: "app.")
            var chosen = CameraFlowPreferences()
            chosen.flashMode = .off
            chosen.aspectRatio = .square
            memory.store(chosen)
            #expect(memory.load() == chosen)
            defaults.set(Data("not a record".utf8), forKey: memory.key)
            #expect(memory.load() == CameraFlowPreferences())
            #expect(defaults.object(forKey: memory.key) == nil)
        }
    }
}
