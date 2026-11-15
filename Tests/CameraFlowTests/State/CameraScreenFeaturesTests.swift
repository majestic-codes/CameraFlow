//
//  CameraScreenFeaturesTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("The costly photo features on the camera screen", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraScreenFeaturesTests {

    @Test("A flow that can use neither feature offers neither on its screen, and takes still HEIF photos")
    func screenWithoutFeatures() async throws {
        var camera = CameraFlowInitialState()
        camera.photoFormat = .fixed(.heif)
        let features = PhotoCaptureFeatures(camera: camera, output: CameraFlowOutput())
        #expect(features == PhotoCaptureFeatures(livePhoto: false, raw: false))
        var captures: [CameraCapture] = []
        let model = PhotoCameraModel(
            service: SimulatedCameraService(scene: .black, features: features),
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            initialState: camera,
            files: CaptureTestSupport.makeFileStore()
        ) { captures.append($0) }
        await model.start()
        #expect(model.settings.isLivePhotoAvailable == false)
        #expect(model.settings.availablePhotoFormats == [CameraFlowPhotoFormat.heif])
        await model.capture()
        let capture = try #require(captures.first)
        #expect(model.notices.captureError == nil)
        #expect(capture.livePhotoMovieURL == nil)
        try CaptureTestSupport.discardFiles(of: capture)
        model.close()
    }

    @Test(
        "The camera has Live Photo on exactly when the screen offers it",
        arguments: [
            CameraFlowSetting.fixed(false), .fixed(true), CameraFlowSetting(false), CameraFlowSetting(true)
        ]
    )
    func livePhotoMatchesScreen(setting: CameraFlowSetting<Bool>) {
        var camera = CameraFlowInitialState()
        camera.isLivePhotoEnabled = setting
        let features = PhotoCaptureFeatures(camera: camera, output: CameraFlowOutput())
        let model = PhotoCameraModel(
            service: SimulatedCameraService(scene: .black, features: features),
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            initialState: camera,
            files: CaptureTestSupport.makeFileStore()
        ) { _ in }
        #expect(model.settings.isLivePhotoOffered == features.livePhoto)
    }
}
