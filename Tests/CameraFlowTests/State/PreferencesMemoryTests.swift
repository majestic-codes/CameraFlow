//
//  PreferencesMemoryTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("The flow remembers the user's choices", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PreferencesMemoryTests {
    private let store = FakePreferenceStore()

    private func makeModel(
        initialState: CameraFlowInitialState = CameraFlowInitialState(),
        service: RecordingCameraService = RecordingCameraService()
    ) -> PhotoCameraModel {
        let memory = CaptureTestSupport.makeMemory(store: store)
        return makeCaptureModel(service: service, initialState: initialState, memory: memory)
    }

    @Test("What the user chose in one flow opens the next one, under one versioned key")
    func rememberedAcrossFlows() throws {
        let first = makeModel()
        first.settings.cycleFlash()
        first.settings.toggleLivePhoto()
        first.settings.select(aspectRatio: .sixteenByNine)
        first.settings.select(timer: .tenSeconds)
        first.settings.select(photoFormat: .raw)
        #expect(store.keys == ["CameraFlow.preferences.v1"])
        let data = try #require(store.data(forKey: "CameraFlow.preferences.v1"))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains(#""flashMode":"on""#))
        #expect(json.contains(#""photoFormat":"RAW""#))
        let second = makeModel()
        #expect(second.settings.flashMode == .alwaysOn)
        #expect(second.settings.isLivePhotoEnabled)
        #expect(second.settings.aspectRatio == .sixteenByNine)
        #expect(second.settings.timer == .tenSeconds)
        #expect(second.settings.photoFormat == .raw)
    }

    @Test("Only what the user changed is remembered: a setting left alone follows the app's value in the next flow")
    func untouchedSettingsNotRemembered() throws {
        let first = makeModel()
        first.settings.cycleFlash()
        first.settings.select(timer: .off)
        let data = try #require(store.data(forKey: "CameraFlow.preferences.v1"))
        #expect(try #require(String(data: data, encoding: .utf8)) == #"{"flashMode":"on"}"#)
        var state = CameraFlowInitialState()
        state.aspectRatio.value = .sixteenByNine
        let second = makeModel(initialState: state)
        #expect(second.settings.flashMode == .alwaysOn)
        #expect(second.settings.aspectRatio == .sixteenByNine)
    }

    @Test("A remembered format the flow does not have reads as none, and the rest of the record is kept")
    func unknownFormat() {
        let damaged = FakePreferenceStore(values: [
            "CameraFlow.preferences.v1": Data(#"{"flashMode":"off","photoFormat":"TIFF"}"#.utf8)
        ])
        let memory = CaptureTestSupport.makeMemory(store: damaged)
        var expected = CameraFlowPreferences()
        expected.flashMode = .off
        #expect(memory.load() == expected)
        #expect(damaged.writeCount == 0)
    }

    @Test("Exposure bias is not remembered, like the stock camera")
    func exposureForgotten() {
        let first = makeModel()
        first.settings.setExposureBias(1.5)
        first.settings.select(timer: .threeSeconds)
        #expect(makeModel().settings.exposureBias == 0)
    }

    @Test("A fixed setting is neither remembered nor changed by what is remembered")
    func fixedSettings() throws {
        let first = makeModel()
        first.settings.cycleFlash()
        first.settings.select(aspectRatio: .square)
        var state = CameraFlowInitialState()
        state.flashMode = .fixed(.off)
        let second = makeModel(initialState: state)
        #expect(second.settings.flashMode == .off)
        #expect(second.settings.aspectRatio == .square)
        second.settings.select(timer: .fiveSeconds)
        let third = makeModel()
        #expect(third.settings.flashMode == .alwaysOn)
        #expect(third.settings.timer == .fiveSeconds)
    }

    @Test("A remembered value the camera lacks is resolved as the panel resolves it, and stays remembered")
    func unsupportedValues() async throws {
        let first = makeModel()
        first.settings.select(photoFormat: .raw)
        let narrow = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.narrowCapabilities)
        let second = makeModel(service: narrow)
        await second.start()
        #expect(second.settings.photoFormat == .raw)
        #expect(second.settings.effectivePhotoFormat == .heif)
        second.settings.select(timer: .threeSeconds)
        let third = makeModel()
        #expect(third.settings.photoFormat == .raw)
    }

    @Test("A stored value that does not decode is discarded once and the app's values are used")
    func corruptData() {
        let corrupt = FakePreferenceStore(values: ["CameraFlow.preferences.v1": Data("not json".utf8)])
        let memory = CaptureTestSupport.makeMemory(store: corrupt)
        let model = makeCaptureModel(service: RecordingCameraService(), memory: memory)
        #expect(model.settings.flashMode == .auto)
        #expect(corrupt.data(forKey: "CameraFlow.preferences.v1") == nil)
        #expect(corrupt.writeCount == 1)
    }

    @Test("A value an older version stored is read for what it has")
    func olderValue() {
        let old = FakePreferenceStore(values: [
            "CameraFlow.preferences.v1": Data(#"{"flashMode":"off","somethingNewer":1}"#.utf8)
        ])
        let memory = CaptureTestSupport.makeMemory(store: old)
        let model = makeCaptureModel(service: RecordingCameraService(), memory: memory)
        #expect(model.settings.flashMode == .off)
        #expect(model.settings.timer == .off)
    }

    @Test("The remembered dual-camera state is carried along untouched until a model owns it")
    func dualCameraCarried() throws {
        var remembered = CameraFlowPreferences()
        remembered.isDualCameraEnabled = true
        let memory = CaptureTestSupport.makeMemory(store: store)
        memory.store(remembered)
        let model = makeModel()
        model.settings.cycleFlash()
        #expect(memory.load().isDualCameraEnabled == true)
        #expect(memory.load().flashMode == .alwaysOn)
    }

    @Test("Without a memory every flow opens with the app's values")
    func optOut() {
        let first = makeCaptureModel(service: RecordingCameraService())
        first.settings.cycleFlash()
        #expect(makeCaptureModel(service: RecordingCameraService()).settings.flashMode == .auto)
    }

    @Test("The memory of a configuration is the standard defaults under the prefix by default, or none")
    func configuration() {
        #expect(CameraFlowConfiguration().settingsMemory == .userDefaults(suiteName: nil, keyPrefix: "CameraFlow."))
        let memory = CaptureTestSupport.makeMemory(store: store)
        #expect(memory.key == "CameraFlow.preferences.v1")
    }
}
