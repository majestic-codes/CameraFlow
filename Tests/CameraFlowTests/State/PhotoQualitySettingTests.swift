//
//  PhotoQualitySettingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("The quality row of the Format panel", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoQualitySettingTests {

    private func makeStartedHarness(
        setting: CameraFlowSetting<CameraFlowQuality> = CameraFlowSetting(.high),
        output: CameraFlowOutput = CameraFlowOutput(),
        initialState: CameraFlowInitialState = CameraFlowInitialState()
    ) async -> QualityHarness {
        let saving = CaptureTestSupport.makeLibrarySaving(isOn: true, isUserAdjustable: false)
        let harness = QualityHarness(
            setting: setting,
            output: output,
            initialState: initialState,
            librarySaving: saving
        )
        return await harness.started()
    }

    // MARK: - The default flow

    @Test("A flow that does not opt in has no quality row, no indicator and nothing to report")
    func defaultFlow() async {
        let model = makeCaptureModel(service: RecordingCameraService(), isLivePhotoOffered: false)
        await model.start()
        let settings = model.settings
        #expect(settings.offeredPhotoQualities.isEmpty)
        #expect(settings.photoQuality == .high)
        #expect(settings.output == CameraFlowOutput())
        #expect(settings.preferences == CameraFlowPreferences())
        #expect(settings.topBarItems == [.flash])
        #expect(settings.offeredPhotoFormats == settings.availablePhotoFormats)
        #expect(settings.deliversPhotos(within: settings.output))
    }

    @Test("A quality the app fixed below high narrows the output without a row or an indicator")
    func fixedQuality() async {
        let harness = await makeStartedHarness(setting: .fixed(.low))
        let settings = harness.settings
        #expect(settings.offeredPhotoQualities.isEmpty)
        #expect(settings.photoQuality == .low)
        #expect(settings.output.size == .standard)
        #expect(settings.changedSettings.isEmpty)
        #expect(settings.preferences.photoQuality == nil)
        #expect(settings.offeredPhotoFormats == [.heif])
        settings.select(photoQuality: .high)
        #expect(settings.photoQuality == .low)
        #expect(harness.outcome.preferences.isEmpty)
    }

    // MARK: - The row

    @Test("An adjustable quality gives the Format tile its row, even with the format fixed")
    func formatTile() {
        var state = CameraFlowInitialState()
        state.photoFormat = .fixed(.heif)
        let adjustable = QualityHarness(setting: CameraFlowSetting(.high), initialState: state)
        #expect(adjustable.settings.isAdjustable(.format))
        #expect(adjustable.settings.offeredSettings.contains(.format))
        #expect(adjustable.settings.offeredPhotoQualities == [.high, .medium, .low])
        let fixed = QualityHarness(setting: .fixed(.high), initialState: state)
        #expect(fixed.settings.isAdjustable(.format) == false)
    }

    @Test("The row leaves out a quality the app's output makes the same as a better one")
    func rowWithinOutput() {
        var output = CameraFlowOutput()
        output.size = .standard
        let harness = QualityHarness(setting: CameraFlowSetting(.medium), output: output)
        #expect(harness.settings.offeredPhotoQualities == [.high, .low])
        #expect(harness.settings.photoQuality == .high)
        #expect(harness.settings.output == output)
    }

    @Test("Choosing a quality plays the selection haptic once and changes the output of the next photo")
    func selecting() async {
        let harness = await makeStartedHarness()
        let settings = harness.settings
        let before = harness.haptics.events.count
        settings.select(photoQuality: .medium)
        settings.select(photoQuality: .medium)
        #expect(Array(harness.haptics.events.dropFirst(before)) == [.optionSelected])
        #expect(settings.photoQuality == .medium)
        #expect(settings.output.size == .standard)
        #expect(settings.output.format == .original)
        settings.select(photoQuality: .low)
        #expect(settings.output.format == .heic(quality: 0.5))
    }

    // MARK: - Preferences

    @Test("Every change of the quality is reported with the choice, and choosing the same one is not")
    func reported() async {
        let harness = await makeStartedHarness()
        let settings = harness.settings
        #expect(settings.preferences.photoQuality == nil)
        settings.select(photoQuality: .high)
        #expect(harness.outcome.preferences.isEmpty)
        settings.select(photoQuality: .low)
        settings.select(photoQuality: .medium)
        #expect(harness.outcome.preferences.map(\.photoQuality) == [.low, .medium])
    }

    @Test("The stored preference opens the next flow with the quality the user left")
    func restored() {
        let harness = QualityHarness(setting: CameraFlowSetting(.high), preference: .medium)
        #expect(harness.settings.photoQuality == .medium)
        #expect(harness.settings.changedSettings == [.format])
    }

    // MARK: - What a reduced quality leaves of the other rows

    @Test(
        "Below the high quality the photos are scaled and no RAW is available, and the format row keeps its options",
        arguments: [CameraFlowQuality.medium, .low]
    )
    func narrowedRows(quality: CameraFlowQuality) async {
        let harness = await makeStartedHarness()
        let settings = harness.settings
        #expect(settings.deliversPhotos(within: settings.output))
        #expect(settings.availablePhotoFormats == [.heif, .raw])
        settings.select(photoQuality: quality)
        #expect(settings.deliversPhotos(within: settings.output) == false)
        #expect(settings.availablePhotoFormats == [.heif])
        #expect(settings.offeredPhotoFormats == [.heif, .raw])
        #expect(settings.effectivePhotoFrame?.isPreferred == true)
    }

    @Test("RAW stays chosen under a reduced quality, is not taken, and comes back with the high one")
    func rawComesBack() async throws {
        let harness = await makeStartedHarness()
        let settings = harness.settings
        settings.select(photoFormat: .raw)
        #expect(settings.effectivePhotoFormat == .raw)
        settings.select(photoQuality: .medium)
        #expect(settings.photoFormat == .raw)
        #expect(settings.effectivePhotoFormat == .heif)
        let capabilities = try #require(harness.camera.session.photoCapabilities)
        #expect(try settings.makeRequest(for: capabilities).format == .heif)
        settings.select(photoQuality: .high)
        #expect(settings.effectivePhotoFormat == .raw)
    }

    @Test("A reduced quality asks the camera for the size the high one does, and the output scales it")
    func request() async throws {
        let harness = await makeStartedHarness()
        let settings = harness.settings
        let capabilities = try #require(harness.camera.session.photoCapabilities)
        #expect(try settings.makeRequest(for: capabilities).resolution.isPreferred)
        settings.select(photoQuality: .low)
        #expect(try settings.makeRequest(for: capabilities).resolution.isPreferred)
        #expect(settings.effectivePhotoFrame?.width == 4032)
    }

    // MARK: - The top bar

    @Test("A quality below high shows the Format indicator, which goes with the high one")
    func indicator() async {
        let harness = await makeStartedHarness()
        let settings = harness.settings
        #expect(settings.changedSettings.isEmpty)
        settings.select(photoQuality: .medium)
        #expect(settings.changedSettings == [.format])
        #expect(settings.topBarItems == [.flash, .format])
        settings.select(aspectRatio: .sixteenByNine)
        #expect(settings.topBarItems == [.flash, .aspect, .format])
        settings.select(photoQuality: .high)
        #expect(settings.changedSettings == [.aspect])
    }
}
