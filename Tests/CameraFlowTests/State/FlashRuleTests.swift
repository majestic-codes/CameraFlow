//
//  FlashRuleTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

/// One flash rule for every running camera, alone or in the pair: the chosen mode where the camera offers it and off
/// where it does not, while the chosen mode stays for a camera that has it.
@MainActor
@Suite("The flash of a camera that offers less than the chosen mode", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FlashRuleTests {
    let haptics = RecordingCameraHaptics()

    private func makeModel(
        service: RecordingCameraService,
        flashMode: CameraFlowFlashMode = .alwaysOn,
        onPreferencesChange: ((CameraFlowPreferences) -> Void)? = nil
    ) -> PhotoCameraModel {
        var state = CameraFlowInitialState()
        state.flashMode.value = flashMode
        return makeCaptureModel(
            service: service,
            haptics: haptics,
            initialState: state,
            onPreferencesChange: onPreferencesChange
        )
    }

    @Test("A camera without a flash cannot take the flash: it is off for its photos and the chosen mode stays")
    func cameraWithoutFlash() async throws {
        let service = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.withoutFlash)
        let model = makeModel(service: service)
        #expect(model.settings.isFlashSelectable)
        await model.start()
        #expect(model.settings.isFlashSelectable == false)
        #expect(model.settings.effectiveFlashMode == .off)
        #expect(model.settings.flashMode == .alwaysOn)
        await model.capture()
        let request = try #require(service.captureRequests.last)
        #expect(request.flashMode == .off)
        #expect(model.notices.captureError == nil)
    }

    @Test("A camera without a flash keeps the chosen mode whatever the indicator and the sub-panel are asked")
    func noChoiceWithoutFlash() async {
        let service = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.withoutFlash)
        var reports: [CameraFlowPreferences] = []
        let model = makeModel(service: service) { reports.append($0) }
        await model.start()
        let monitored = service.monitoredFlashModes
        haptics.removeAll()
        model.settings.flashIndicatorTapped()
        model.settings.cycleFlash()
        model.settings.select(flashMode: .auto)
        #expect(model.settings.flashMode == .alwaysOn)
        #expect(model.settings.effectiveFlashMode == .off)
        #expect(service.monitoredFlashModes == monitored)
        #expect(haptics.events.isEmpty)
        #expect(reports.isEmpty)
    }

    @Test("The chosen mode comes back with a camera that has a flash")
    func modeComesBack() async throws {
        let service = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.withoutFlash)
        let model = makeModel(service: service)
        await model.start()
        #expect(model.settings.effectiveFlashMode == .off)
        await model.flipCamera()
        #expect(model.settings.isFlashSelectable)
        #expect(model.settings.effectiveFlashMode == .alwaysOn)
        await model.capture()
        let request = try #require(service.captureRequests.last)
        #expect(request.flashMode == .alwaysOn)
        await model.flipCamera()
        #expect(model.settings.effectiveFlashMode == .off)
        #expect(model.settings.flashMode == .alwaysOn)
    }

    @Test("Before a camera has started the flash takes the chosen mode")
    func beforeStart() {
        let model = makeModel(service: RecordingCameraService(), flashMode: .off)
        #expect(model.settings.isFlashSelectable)
        #expect(model.settings.effectiveFlashMode == .off)
        model.settings.cycleFlash()
        #expect(model.settings.effectiveFlashMode == .auto)
    }

    @Test("A camera that offers some modes takes the chosen one where it has it and off otherwise, never refusing it")
    func someModes() async throws {
        let some = PhotoCaptureCapabilities(
            flashModes: [.off, .alwaysOn],
            isLivePhotoSupported: true,
            exposureBiasRange: -8...8,
            formats: [.heif],
            encodesHEVC: true,
            resolution: SimulatedCameraService.iPhoneBackPhotoCapabilities.resolution,
            lockableAdjustments: .focusAndExposure
        )
        let service = RecordingCameraService(backPhotoCapabilities: some)
        let model = makeModel(service: service, flashMode: .auto)
        await model.start()
        #expect(model.settings.isFlashSelectable)
        #expect(model.settings.effectiveFlashMode == .off)
        await model.capture()
        #expect(service.captureRequests.last?.flashMode == .off)
        #expect(model.notices.captureError == nil)
        model.settings.cycleFlash()
        #expect(model.settings.effectiveFlashMode == .alwaysOn)
        await model.capture()
        let request = try #require(service.captureRequests.last)
        #expect(request.flashMode == .alwaysOn)
    }

    @Test("The pair follows the same rule: a pair without a flash leaves the chosen mode for the camera alone")
    func pairWithoutFlash() async {
        let service = RecordingCameraService(dualPhotoCapabilities: CaptureTestSupport.dualWithoutFlash)
        var state = DualCameraFixture.keptState
        state.flashMode.value = .auto
        let model = makeCaptureModel(service: service, initialState: state, isDualCameraOffered: true)
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await model.start()
        await model.toggleDualCamera()
        #expect(model.settings.isFlashSelectable == false)
        #expect(model.settings.effectiveFlashMode == .off)
        model.settings.cycleFlash()
        #expect(model.settings.flashMode == .auto)
        await model.toggleDualCamera()
        #expect(model.settings.isFlashSelectable)
        #expect(model.settings.effectiveFlashMode == .auto)
    }
}
