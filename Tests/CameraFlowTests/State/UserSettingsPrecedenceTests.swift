//
//  UserSettingsPrecedenceTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// Which of the values a user setting may open with wins.
struct SettingSources: Sendable, CustomTestStringConvertible {
    enum Winner: Sendable {
        case appValue
        case appPreference
        case memory
    }

    let isFixed: Bool
    let hasAppPreference: Bool
    let isRemembered: Bool
    let winner: Winner

    /// The app's value fixed, the app's preference, the remembered value, the app's value, in this order.
    static let all = [
        Self(isFixed: false, hasAppPreference: false, isRemembered: false, winner: .appValue),
        Self(isFixed: false, hasAppPreference: false, isRemembered: true, winner: .memory),
        Self(isFixed: false, hasAppPreference: true, isRemembered: false, winner: .appPreference),
        Self(isFixed: false, hasAppPreference: true, isRemembered: true, winner: .appPreference),
        Self(isFixed: true, hasAppPreference: false, isRemembered: false, winner: .appValue),
        Self(isFixed: true, hasAppPreference: false, isRemembered: true, winner: .appValue),
        Self(isFixed: true, hasAppPreference: true, isRemembered: false, winner: .appValue),
        Self(isFixed: true, hasAppPreference: true, isRemembered: true, winner: .appValue)
    ]

    var testDescription: String {
        let kind = isFixed ? "fixed" : "adjustable"
        let preference = hasAppPreference ? "an app preference" : "no app preference"
        let memory = isRemembered ? "a remembered value" : "nothing remembered"
        return "\(kind), \(preference), \(memory)"
    }

    func setting<Value>(_ value: Value) -> CameraFlowSetting<Value> {
        CameraFlowSetting(value, isUserAdjustable: !isFixed)
    }

    /// The value that wins among three different ones.
    func expected<Value>(appValue: Value, appPreference: Value, remembered: Value) -> Value {
        switch winner {
        case .appValue: appValue
        case .appPreference: appPreference
        case .memory: remembered
        }
    }

    /// A switch has two positions, so the app's preference is the opposite of the app's value, and the remembered
    /// position is the one that tells the memory from whatever it competes with.
    func toggles(appValue: Bool) -> (appPreference: Bool, remembered: Bool) {
        (!appValue, hasAppPreference ? appValue : !appValue)
    }
}

@MainActor
@Suite(
    "A user setting opens fixed, or with the app's preference, or the remembered value, or the app's value",
    .temporaryDirectory,
    .timeLimit(.minutes(1))
)
struct UserSettingsPrecedenceTests {
    private let store = FakePreferenceStore()

    /// The app's preferences and a memory holding the remembered ones, each only where the sources have it.
    private func makeStored(
        _ sources: SettingSources,
        appPreference: (inout CameraFlowPreferences) -> Void,
        remembered: (inout CameraFlowPreferences) -> Void
    ) -> (preferences: CameraFlowPreferences, memory: PreferencesMemory) {
        let memory = CaptureTestSupport.makeMemory(store: store)
        var preferences = CameraFlowPreferences()
        if sources.hasAppPreference {
            appPreference(&preferences)
        }
        if sources.isRemembered {
            var record = CameraFlowPreferences()
            remembered(&record)
            memory.store(record)
        }
        return (preferences, memory)
    }

    @Test("The flash mode, an enumeration", arguments: SettingSources.all)
    func flashMode(sources: SettingSources) {
        let stored = makeStored(sources) { $0.flashMode = .off } remembered: { $0.flashMode = .alwaysOn }
        var state = CameraFlowInitialState()
        state.flashMode = sources.setting(.auto)
        let model = makeCaptureModel(
            service: RecordingCameraService(),
            initialState: state,
            preferences: stored.preferences,
            memory: stored.memory
        )
        let expected = sources.expected(appValue: CameraFlowFlashMode.auto, appPreference: .off, remembered: .alwaysOn)
        #expect(model.settings.flashMode == expected)
    }

    @Test("The timer, an enumeration", arguments: SettingSources.all)
    func timer(sources: SettingSources) {
        let stored = makeStored(sources) { $0.timer = .fiveSeconds } remembered: { $0.timer = .tenSeconds }
        var state = CameraFlowInitialState()
        state.timer = sources.setting(.threeSeconds)
        let model = makeCaptureModel(
            service: RecordingCameraService(),
            initialState: state,
            preferences: stored.preferences,
            memory: stored.memory
        )
        let expected = sources.expected(
            appValue: CameraFlowTimer.threeSeconds,
            appPreference: .fiveSeconds,
            remembered: .tenSeconds
        )
        #expect(model.settings.timer == expected)
    }

    @Test("Live Photo, a switch", arguments: SettingSources.all, [false, true])
    func livePhoto(sources: SettingSources, appValue: Bool) {
        let toggles = sources.toggles(appValue: appValue)
        let stored = makeStored(sources) {
            $0.isLivePhotoEnabled = toggles.appPreference
        } remembered: {
            $0.isLivePhotoEnabled = toggles.remembered
        }
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled = sources.setting(appValue)
        let model = PhotoCameraModel(
            service: RecordingCameraService(),
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            initialState: state,
            preferences: stored.preferences,
            memory: stored.memory,
            files: CaptureTestSupport.makeFileStore()
        ) { _ in }
        let expected = sources.expected(
            appValue: appValue,
            appPreference: toggles.appPreference,
            remembered: toggles.remembered
        )
        #expect(model.settings.isLivePhotoEnabled == expected)
    }

    @Test("The second camera's circle, a switch", arguments: SettingSources.all, [false, true])
    func dualCamera(sources: SettingSources, appValue: Bool) {
        let toggles = sources.toggles(appValue: appValue)
        let stored = makeStored(sources) {
            $0.isDualCameraEnabled = toggles.appPreference
        } remembered: {
            $0.isDualCameraEnabled = toggles.remembered
        }
        var state = CameraFlowInitialState()
        state.isDualCameraEnabled = sources.setting(appValue)
        let model = makeCaptureModel(
            service: RecordingCameraService(),
            initialState: state,
            isDualCameraOffered: true,
            preferences: stored.preferences,
            memory: stored.memory
        )
        let expected = sources.expected(
            appValue: appValue,
            appPreference: toggles.appPreference,
            remembered: toggles.remembered
        )
        #expect(model.settings.opensWithDualCamera == expected)
    }

    @Test("Saving to the photo library, a switch", arguments: SettingSources.all, [false, true])
    func librarySaving(sources: SettingSources, appValue: Bool) {
        let toggles = sources.toggles(appValue: appValue)
        let stored = makeStored(sources) {
            $0.isPhotoLibrarySavingEnabled = toggles.appPreference
        } remembered: {
            $0.isPhotoLibrarySavingEnabled = toggles.remembered
        }
        var saving = CameraFlowPhotoLibrarySaving()
        saving.isEnabled = sources.setting(appValue)
        let choices = UserChoices(preferences: stored.preferences, memory: stored.memory, onChange: nil)
        let isOn = choices.opensLibrarySaving(saving)
        let expected = sources.expected(
            appValue: appValue,
            appPreference: toggles.appPreference,
            remembered: toggles.remembered
        )
        #expect(isOn == expected)
    }

    @Test("The quality of the photos", arguments: SettingSources.all)
    func photoQuality(sources: SettingSources) {
        let stored = makeStored(sources) { $0.photoQuality = .low } remembered: { $0.photoQuality = .medium }
        let harness = QualityHarness(
            setting: sources.setting(.high),
            preference: stored.preferences.photoQuality,
            memory: stored.memory
        )
        let expected = sources.expected(appValue: CameraFlowQuality.high, appPreference: .low, remembered: .medium)
        #expect(harness.settings.photoQuality == expected)
        #expect(harness.quality.quality == expected)
    }
}
