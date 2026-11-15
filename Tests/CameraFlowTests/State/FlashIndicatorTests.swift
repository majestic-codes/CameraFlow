//
//  FlashIndicatorTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

/// The Flash indicator lit like the stock one while the next photo fires the flash, from the scene the running camera
/// monitors for the chosen mode.
@MainActor
@Suite("The Flash indicator and the scene of the camera", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FlashIndicatorTests {
    /// A flash mode, whether the camera reports its scene dark enough for the flash, and whether the indicator is lit.
    struct LitCase: Sendable, CustomTestStringConvertible {
        let mode: CameraFlowFlashMode
        let isFlashScene: Bool
        let isLit: Bool

        var testDescription: String {
            "\(mode), \(isFlashScene ? "dark" : "bright") scene"
        }
    }

    nonisolated static let litCases = [
        LitCase(mode: .auto, isFlashScene: false, isLit: false),
        LitCase(mode: .auto, isFlashScene: true, isLit: true),
        LitCase(mode: .alwaysOn, isFlashScene: false, isLit: true),
        LitCase(mode: .alwaysOn, isFlashScene: true, isLit: true),
        LitCase(mode: .off, isFlashScene: false, isLit: false),
        LitCase(mode: .off, isFlashScene: true, isLit: false)
    ]

    private func makeStartedModel(
        service: RecordingCameraService = RecordingCameraService(),
        flashMode: CameraFlowFlashMode
    ) async -> PhotoCameraModel {
        var state = CameraFlowInitialState()
        state.flashMode.value = flashMode
        let model = makeCaptureModel(service: service, initialState: state)
        await model.start()
        return model
    }

    @Test(
        "The indicator is lit while the next photo fires the flash: in On, and in Auto in a dark scene",
        arguments: litCases
    )
    func lit(litCase: LitCase) async {
        let service = RecordingCameraService()
        let model = await makeStartedModel(service: service, flashMode: litCase.mode)
        await service.simulate(.flashSceneChanged(litCase.isFlashScene))
        #expect(model.settings.isFlashLit == litCase.isLit)
        #expect(model.settings.flashUnavailability == nil)
    }

    @Test("Auto turns the indicator yellow when the scene gets dark and white again when it gets bright")
    func autoFollowsTheScene() async {
        let service = RecordingCameraService()
        let model = await makeStartedModel(service: service, flashMode: .auto)
        #expect(model.settings.isFlashLit == false)
        await service.simulate(.flashSceneChanged(true))
        #expect(model.settings.isFlashLit)
        await service.simulate(.flashSceneChanged(false))
        #expect(model.settings.isFlashLit == false)
    }

    @Test("A camera without a flash never lights the indicator, whatever its scene")
    func unlitWithoutFlash() async {
        let service = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.withoutFlash)
        let model = await makeStartedModel(service: service, flashMode: .alwaysOn)
        await service.simulate(.flashSceneChanged(true))
        #expect(model.settings.isFlashLit == false)
        #expect(model.settings.isFlashSelectable == false)
    }

    @Test("A flash that cannot fire leaves the indicator unlit and shows it unavailable until it can again")
    func unlitWhileUnavailable() async {
        let service = RecordingCameraService()
        let model = await makeStartedModel(service: service, flashMode: .auto)
        await service.simulate(.flashSceneChanged(true))
        await service.simulate(.flashAvailabilityChanged(.unavailable(.heat)))
        #expect(model.settings.isFlashLit == false)
        #expect(model.settings.flashUnavailability == .heat)
        #expect(model.settings.isFlashSelectable)
        await service.simulate(.flashAvailabilityChanged(.available))
        #expect(model.settings.isFlashLit)
        #expect(model.settings.flashUnavailability == nil)
    }

    @Test("The camera monitors its scene for the chosen mode: from its start and after every change of the mode")
    func monitoredMode() async {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service)
        #expect(service.monitoredFlashModes.isEmpty)
        await model.start()
        #expect(service.monitoredFlashModes == [.auto])
        model.settings.cycleFlash()
        model.settings.select(flashMode: .off)
        model.settings.select(flashMode: .off)
        #expect(service.monitoredFlashModes == [.auto, .alwaysOn, .off])
    }

    @Test("Every camera that starts monitors its scene for the chosen mode, a camera without a flash too")
    func monitoredByEveryCamera() async {
        let service = RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.withoutFlash)
        let model = await makeStartedModel(service: service, flashMode: .alwaysOn)
        await model.flipCamera()
        await model.flipCamera()
        #expect(service.monitoredFlashModes == [.alwaysOn, .alwaysOn, .alwaysOn])
    }
}
