//
//  FlashSceneFormatTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

/// The scene the camera monitors for the Auto flash, as the next photo would be taken: in the chosen mode and in the
/// format the capture uses, whose quality prioritization moves the light level the flash fires at. The camera hears
/// it again whenever that format moves, and only then.
@MainActor
@Suite("The flash scene and the format of the next photo", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FlashSceneFormatTests {

    @Test("A change of the format has the camera monitor its scene in the new one, and the same format says nothing")
    func formatChange() async {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service)
        await model.start()
        #expect(service.monitoredFlashScenes == [MonitoredFlashScene(flashMode: .auto, format: .heif)])
        model.settings.select(photoFormat: .raw)
        model.settings.select(photoFormat: .raw)
        model.settings.select(photoFormat: .heif)
        #expect(
            service.monitoredFlashScenes == [
                MonitoredFlashScene(flashMode: .auto, format: .heif),
                MonitoredFlashScene(flashMode: .auto, format: .raw),
                MonitoredFlashScene(flashMode: .auto, format: .heif)
            ]
        )
    }

    @Test("A change of the flash mode is monitored in the format the capture uses")
    func flashModeChange() async {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service)
        await model.start()
        model.settings.select(photoFormat: .raw)
        model.settings.cycleFlash()
        model.settings.select(flashMode: .off)
        #expect(
            service.monitoredFlashScenes.suffix(2) == [
                MonitoredFlashScene(flashMode: .alwaysOn, format: .raw),
                MonitoredFlashScene(flashMode: .off, format: .raw)
            ]
        )
    }

    @Test("A quality that leaves no RAW moves the monitoring to HEIF, and the high quality brings RAW back")
    func qualityChange() async {
        let harness = QualityHarness()
        await harness.camera.start()
        let settings = harness.settings
        settings.select(photoFormat: .raw)
        let monitored = harness.service.monitoredFlashScenes.count
        settings.select(photoQuality: .medium)
        settings.select(photoQuality: .low)
        settings.select(photoQuality: .high)
        #expect(settings.photoFormat == .raw)
        #expect(
            Array(harness.service.monitoredFlashScenes.dropFirst(monitored)) == [
                MonitoredFlashScene(flashMode: .auto, format: .heif),
                MonitoredFlashScene(flashMode: .auto, format: .raw)
            ]
        )
    }

    @Test("A camera without RAW is monitored for HEIF while RAW stays chosen, and RAW comes back with the other camera")
    func cameraChange() async {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service)
        await model.start()
        model.settings.select(photoFormat: .raw)
        await model.flipCamera()
        #expect(service.monitoredFlashScenes.last == MonitoredFlashScene(flashMode: .auto, format: .heif))
        #expect(model.settings.photoFormat == .raw)
        await model.flipCamera()
        #expect(service.monitoredFlashScenes.last == MonitoredFlashScene(flashMode: .auto, format: .raw))
    }
}
