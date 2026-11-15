//
//  FlashUnavailableTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

/// A flash that cannot fire for a while, because the device is too hot or its battery too low: the photos go without
/// it, and a tap on the Flash indicator says why instead of changing the mode.
@MainActor
@Suite("A flash that cannot fire for a while", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FlashUnavailableTests {
    let service = RecordingCameraService()

    private func makeStartedModel(flashMode: CameraFlowFlashMode = .alwaysOn) async -> PhotoCameraModel {
        var state = CameraFlowInitialState()
        state.flashMode.value = flashMode
        let model = makeCaptureModel(service: service, initialState: state)
        await model.start()
        return model
    }

    @Test("Photos go without the flash while it cannot fire, and with the chosen mode once it can again")
    func photosWithoutFlash() async throws {
        let model = await makeStartedModel()
        await service.simulate(.flashAvailabilityChanged(.unavailable(.heat)))
        await model.capture()
        let withoutFlash = try #require(service.captureRequests.last)
        #expect(withoutFlash.flashMode == .off)
        #expect(model.settings.flashMode == .alwaysOn)
        #expect(model.settings.effectiveFlashMode == .alwaysOn)
        await service.simulate(.flashAvailabilityChanged(.available))
        await model.capture()
        let withFlash = try #require(service.captureRequests.last)
        #expect(withFlash.flashMode == .alwaysOn)
    }

    @Test(
        "A tap on the indicator says why the flash cannot fire and keeps the mode",
        arguments: [FlashUnavailability.heat, .power]
    )
    func tapExplains(reason: FlashUnavailability) async {
        let model = await makeStartedModel()
        await service.simulate(.flashAvailabilityChanged(.unavailable(reason)))
        let monitored = service.monitoredFlashModes
        model.settings.flashIndicatorTapped()
        #expect(model.settings.flash.explanation == reason)
        #expect(model.settings.flashMode == .alwaysOn)
        #expect(service.monitoredFlashModes == monitored)
    }

    @Test("The camera's latest reason is the one a tap gives")
    func latestReason() async {
        let model = await makeStartedModel()
        await service.simulate(.flashAvailabilityChanged(.unavailable(.heat)))
        await service.simulate(.flashAvailabilityChanged(.unavailable(.power)))
        #expect(model.settings.flashUnavailability == .power)
        model.settings.flashIndicatorTapped()
        #expect(model.settings.flash.explanation == .power)
    }

    @Test("The explanation closes when the user dismisses it, and a new tap gives it again")
    func dismissed() async {
        let model = await makeStartedModel()
        await service.simulate(.flashAvailabilityChanged(.unavailable(.heat)))
        model.settings.flashIndicatorTapped()
        model.settings.dismissFlashExplanation()
        #expect(model.settings.flash.explanation == nil)
        #expect(model.settings.flashUnavailability == .heat)
        model.settings.flashIndicatorTapped()
        #expect(model.settings.flash.explanation == .heat)
    }

    @Test("The explanation closes by itself once the flash can fire again, and a tap then changes the mode")
    func closesWhenAvailable() async {
        let model = await makeStartedModel()
        await service.simulate(.flashAvailabilityChanged(.unavailable(.heat)))
        model.settings.flashIndicatorTapped()
        await service.simulate(.flashAvailabilityChanged(.available))
        #expect(model.settings.flash.explanation == nil)
        model.settings.flashIndicatorTapped()
        #expect(model.settings.flashMode == .off)
        #expect(model.settings.flash.explanation == nil)
    }

    @Test("A tap on the indicator of a flash that can fire changes the mode and explains nothing")
    func tapCycles() async {
        let model = await makeStartedModel(flashMode: .auto)
        model.settings.flashIndicatorTapped()
        #expect(model.settings.flashMode == .alwaysOn)
        #expect(model.settings.flash.explanation == nil)
    }

    @Test("The sub-panel takes a choice while the flash cannot fire, which the photos take once it can")
    func choiceWhileUnavailable() async throws {
        let model = await makeStartedModel()
        await service.simulate(.flashAvailabilityChanged(.unavailable(.power)))
        model.settings.select(flashMode: .auto)
        #expect(model.settings.flashMode == .auto)
        #expect(service.monitoredFlashModes.last == .auto)
        await service.simulate(.flashAvailabilityChanged(.available))
        await model.capture()
        let request = try #require(service.captureRequests.last)
        #expect(request.flashMode == .auto)
    }

    @Test("A camera without a flash shows no flash unavailable and takes no tap, whatever it reports")
    func cameraWithoutFlash() async {
        let service = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.withoutFlash)
        let model = makeCaptureModel(service: service)
        await model.start()
        await service.simulate(.flashAvailabilityChanged(.unavailable(.heat)))
        #expect(model.settings.flashUnavailability == nil)
        model.settings.flashIndicatorTapped()
        #expect(model.settings.flash.explanation == nil)
        #expect(model.settings.flashMode == .auto)
    }
}
