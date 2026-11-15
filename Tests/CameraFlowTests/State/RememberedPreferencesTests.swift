//
//  RememberedPreferencesTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// Remembered preferences with a value of no known kind: the property reads as nil, the others are kept, and the
/// memory hears which one went.
@Suite("Remembered preferences that are not all known")
struct RememberedPreferencesTests {

    @Test("A stored value of no known kind reads as nil, the others are kept, and its key is named")
    func unknownValue() throws {
        let json = #"{"flashMode":"strobe","timer":3,"photoQuality":{"level":7},"aspectRatio":"16:9"}"#
        let remembered = try JSONDecoder().decode(RememberedPreferences.self, from: Data(json.utf8))
        #expect(remembered.preferences.flashMode == nil)
        #expect(remembered.preferences.timer == .threeSeconds)
        #expect(remembered.preferences.photoQuality == nil)
        #expect(remembered.droppedKeys == ["flashMode", "photoQuality"])
    }

    @Test("A switch stored as anything but a Boolean reads as nil, the others are kept, and its key is named")
    func switchNotABoolean() throws {
        let json = #"{"isLivePhotoEnabled":"enabled","isDualCameraEnabled":1,"isPhotoLibrarySavingEnabled":true}"#
        let remembered = try JSONDecoder().decode(RememberedPreferences.self, from: Data(json.utf8))
        #expect(remembered.preferences.isLivePhotoEnabled == nil)
        #expect(remembered.preferences.isDualCameraEnabled == nil)
        #expect(remembered.preferences.isPhotoLibrarySavingEnabled == true)
        #expect(remembered.droppedKeys == ["isLivePhotoEnabled", "isDualCameraEnabled"])
    }

    @Test("Known values and missing ones drop nothing")
    func knownValues() throws {
        let json = #"{"flashMode":"on","isLivePhotoEnabled":false}"#
        let remembered = try JSONDecoder().decode(RememberedPreferences.self, from: Data(json.utf8))
        #expect(remembered.preferences.flashMode == .alwaysOn)
        #expect(remembered.preferences.isLivePhotoEnabled == false)
        #expect(remembered.droppedKeys.isEmpty)
    }

    @Test("The memory opens with what it could read")
    func memoryKeepsTheRest() {
        let store = FakePreferenceStore()
        let memory = PreferencesMemory(store: store, keyPrefix: "test.")
        store.set(Data(#"{"flashMode":"strobe","timer":10}"#.utf8), forKey: memory.key)
        let loaded = memory.load()
        #expect(loaded.flashMode == nil)
        #expect(loaded.timer == .tenSeconds)
    }
}
