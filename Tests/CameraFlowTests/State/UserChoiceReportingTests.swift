//
//  UserChoiceReportingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("The user's choices are reported and remembered", .temporaryDirectory, .timeLimit(.minutes(1)))
struct UserChoiceReportingTests {
    private let store = FakePreferenceStore()
    private let reported = ReportedPreferences()

    private var memory: PreferencesMemory {
        CaptureTestSupport.makeMemory(store: store)
    }

    /// A flow where the user may change every setting of group 2: Live Photo and the circle are offered, saving
    /// is a switch that opens off, and the quality is a choice inside the output.
    private func makeModel(
        service: RecordingCameraService = RecordingCameraService(),
        output: CameraFlowOutput = CameraFlowOutput(),
        preferences: CameraFlowPreferences = CameraFlowPreferences(),
        memory: PreferencesMemory? = nil,
        writer: FakePhotoLibraryWriter = FakePhotoLibraryWriter()
    ) -> PhotoCameraModel {
        let opening = UserChoices(preferences: preferences, memory: memory, onChange: nil)
        var saving = CameraFlowPhotoLibrarySaving()
        saving.isEnabled = CameraFlowSetting(false)
        let librarySaving = PhotoLibrarySavingModel(
            saving: saving,
            isOn: opening.opensLibrarySaving(saving),
            writer: writer
        )
        let quality = PhotoQualityModel(
            setting: CameraFlowSetting(.high),
            preference: opening.reported.photoQuality,
            output: output
        )
        let report: (CameraFlowPreferences) -> Void = { [reported] in reported.values.append($0) }
        let model = makeCaptureModel(
            service: service,
            isDualCameraOffered: true,
            output: output,
            quality: quality,
            preferences: preferences,
            memory: memory,
            librarySaving: librarySaving,
            onPreferencesChange: report
        )
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        return model
    }

    /// What the user stored in an earlier flow that a narrow camera and a small output cannot honour.
    private static var demanding: CameraFlowPreferences {
        var preferences = CameraFlowPreferences()
        preferences.photoFormat = .raw
        preferences.isDualCameraEnabled = true
        preferences.isPhotoLibrarySavingEnabled = true
        preferences.photoQuality = .medium
        return preferences
    }

    private static var standardOutput: CameraFlowOutput {
        var output = CameraFlowOutput()
        output.size = .standard
        return output
    }

    // MARK: - Reporting

    @Test("Every setting of group 2 is reported when the user changes it, with everything chosen before")
    func everySettingReported() async {
        let model = makeModel()
        await model.start()
        let settings = model.settings
        var expected = CameraFlowPreferences()
        var steps: [CameraFlowPreferences] = []
        settings.cycleFlash()
        expected.flashMode = .alwaysOn
        steps.append(expected)
        settings.toggleLivePhoto()
        expected.isLivePhotoEnabled = true
        steps.append(expected)
        settings.select(aspectRatio: .square)
        expected.aspectRatio = .square
        steps.append(expected)
        settings.select(timer: .fiveSeconds)
        expected.timer = .fiveSeconds
        steps.append(expected)
        settings.select(photoFormat: .raw)
        expected.photoFormat = .raw
        steps.append(expected)
        await model.toggleDualCamera()
        expected.isDualCameraEnabled = true
        steps.append(expected)
        settings.select(photoQuality: .low)
        expected.photoQuality = .low
        steps.append(expected)
        await settings.toggleLibrarySaving()
        expected.isPhotoLibrarySavingEnabled = true
        steps.append(expected)
        #expect(reported.values == steps)
        #expect(settings.preferences == expected)
    }

    @Test("A value chosen again, the exposure bias and the zoom are not reported")
    func nothingToReport() async {
        let model = makeModel()
        await model.start()
        let settings = model.settings
        settings.select(flashMode: .auto)
        settings.select(isLivePhotoEnabled: false)
        settings.select(aspectRatio: .fourByThree)
        settings.select(timer: .off)
        settings.select(photoFormat: .heif)
        settings.select(photoQuality: .high)
        await settings.select(isLibrarySavingEnabled: false)
        settings.setExposureBias(1)
        model.zoom.setZoom(2)
        #expect(reported.values.isEmpty)
        #expect(settings.preferences == CameraFlowPreferences())
    }

    @Test("A setting the app fixed is neither reported nor remembered, whatever is done to it")
    func fixedNotReported() {
        var state = CameraFlowInitialState()
        state.flashMode = .fixed(.off)
        state.isLivePhotoEnabled = .fixed(true)
        let report: (CameraFlowPreferences) -> Void = { [reported] in reported.values.append($0) }
        let model = makeCaptureModel(
            service: RecordingCameraService(),
            initialState: state,
            memory: memory,
            onPreferencesChange: report
        )
        model.settings.cycleFlash()
        model.settings.toggleLivePhoto()
        #expect(reported.values.isEmpty)
        #expect(store.writeCount == 0)
    }

    // MARK: - What the flow resolves on its own

    @Test("Stored choices the camera cannot honour open as the nearest it can, with nothing reported or stored")
    func softResolutionIsSilent() async {
        memory.store(Self.demanding)
        let writes = store.writeCount
        let service = RecordingCameraService(
            backPhotoCapabilities: CaptureTestSupport.narrowCapabilities,
            isDualCameraSupported: false
        )
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .denied)
        let model = makeModel(service: service, output: Self.standardOutput, memory: memory, writer: writer)
        await model.start()
        let settings = model.settings
        #expect(settings.effectivePhotoFormat == .heif)
        #expect(settings.effectivePhotoFrame?.isPreferred == true)
        #expect(model.dualCamera.isOn == false)
        #expect(settings.photoQuality == .high)
        await model.capture()
        #expect(model.notices.captureError == nil)
        #expect(reported.values.isEmpty)
        #expect(store.writeCount == writes)
        #expect(settings.preferences == Self.demanding)
    }

    @Test("A change the user makes afterwards leaves the choices the camera could not honour as they were")
    func softResolutionKeepsChoices() async {
        memory.store(Self.demanding)
        let service = RecordingCameraService(
            backPhotoCapabilities: CaptureTestSupport.narrowCapabilities,
            isDualCameraSupported: false
        )
        let model = makeModel(service: service, output: Self.standardOutput, memory: memory)
        await model.start()
        model.settings.select(timer: .threeSeconds)
        var expected = Self.demanding
        expected.timer = .threeSeconds
        #expect(reported.values == [expected])
        #expect(memory.load() == expected)
    }

    // MARK: - The memory

    @Test("The quality and the saving are remembered with the camera choices and open the next flow")
    func memoryRoundTrip() async throws {
        let first = makeModel(memory: memory)
        await first.start()
        first.settings.select(photoQuality: .low)
        await first.settings.toggleLibrarySaving()
        first.settings.select(aspectRatio: .sixteenByNine)
        let data = try #require(store.data(forKey: "CameraFlow.preferences.v1"))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains(#""photoQuality":"low""#))
        #expect(json.contains(#""isPhotoLibrarySavingEnabled":true"#))
        let second = makeModel(memory: memory)
        #expect(second.settings.photoQuality == .low)
        #expect(second.settings.isLibrarySavingOn)
        #expect(second.settings.aspectRatio == .sixteenByNine)
        #expect(second.settings.preferences == first.settings.preferences)
    }

    @Test("A record that holds some of the choices opens the flow, and is added to")
    func partialRecord() {
        let stored = #"{"flashMode":"off","isLivePhotoEnabled":true,"timer":5}"#
        store.set(Data(stored.utf8), forKey: "CameraFlow.preferences.v1")
        let model = makeModel(memory: memory)
        #expect(model.settings.flashMode == .off)
        #expect(model.settings.isLivePhotoEnabled)
        #expect(model.settings.timer == .fiveSeconds)
        #expect(model.settings.photoQuality == .high)
        model.settings.select(photoQuality: .medium)
        var expected = CameraFlowPreferences()
        expected.flashMode = .off
        expected.isLivePhotoEnabled = true
        expected.timer = .fiveSeconds
        expected.photoQuality = .medium
        #expect(memory.load() == expected)
    }

    @Test("A record with one damaged value opens the flow with the others")
    func damagedValue() {
        let stored = #"{"flashMode":"strobe","photoQuality":"low","timer":"soon","aspectRatio":"1:1"}"#
        store.set(Data(stored.utf8), forKey: "CameraFlow.preferences.v1")
        let model = makeModel(memory: memory)
        #expect(model.settings.flashMode == .auto)
        #expect(model.settings.timer == .off)
        #expect(model.settings.photoQuality == .low)
        #expect(model.settings.aspectRatio == .square)
    }

    @Test("With the memory off the app's stored preferences open the flow, and what is reported opens the next")
    func memoryOff() async {
        var stored = CameraFlowPreferences()
        stored.flashMode = .off
        stored.photoQuality = .medium
        let first = makeModel(preferences: stored)
        await first.start()
        #expect(first.settings.flashMode == .off)
        #expect(first.settings.photoQuality == .medium)
        first.settings.select(timer: .tenSeconds)
        await first.settings.toggleLibrarySaving()
        var expected = stored
        expected.timer = .tenSeconds
        expected.isPhotoLibrarySavingEnabled = true
        #expect(reported.values.last == expected)
        #expect(store.writeCount == 0)
        let second = makeModel(preferences: expected)
        #expect(second.settings.timer == .tenSeconds)
        #expect(second.settings.isLibrarySavingOn)
        #expect(makeModel().settings.timer == .off)
    }

    @Test("The app's stored preferences go before the memory and are not written into it")
    func appPreferencesOverMemory() {
        var remembered = CameraFlowPreferences()
        remembered.flashMode = .alwaysOn
        remembered.aspectRatio = .square
        memory.store(remembered)
        var stored = CameraFlowPreferences()
        stored.flashMode = .off
        let model = makeModel(preferences: stored, memory: memory)
        #expect(model.settings.flashMode == .off)
        #expect(model.settings.aspectRatio == .square)
        model.settings.select(timer: .threeSeconds)
        var expectedReport = remembered
        expectedReport.flashMode = .off
        expectedReport.timer = .threeSeconds
        #expect(reported.values == [expectedReport])
        var expectedMemory = remembered
        expectedMemory.timer = .threeSeconds
        #expect(memory.load() == expectedMemory)
    }
}
