//
//  LockedSettingsTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Settings the app fixes or lets the user change", .temporaryDirectory, .timeLimit(.minutes(1)))
struct LockedSettingsTests {

    @Test("By default every camera setting is adjustable but Live Photo, and saving is off and fixed")
    func defaults() {
        let state = CameraFlowInitialState()
        #expect(state.flashMode == CameraFlowSetting(.auto))
        #expect(state.isLivePhotoEnabled == .fixed(false))
        #expect(state.aspectRatio == CameraFlowSetting(.fourByThree))
        #expect(state.timer == CameraFlowSetting(.off))
        #expect(state.exposureBias == CameraFlowSetting(0))
        #expect(state.photoFormat == CameraFlowSetting(.heif))
        let model = makeCaptureModel(service: RecordingCameraService(), isLivePhotoOffered: false)
        #expect(model.settings.offeredSettings == [.flash, .aspect, .timer, .exposure, .format])
        #expect(model.settings.topBarSettings == [.flash])
        #expect(model.panel.settings == model.settings.offeredSettings)
    }

    @Test("A fixed setting has no tile or indicator and keeps its value")
    func fixedSettings() async throws {
        var state = CameraFlowInitialState()
        state.flashMode = .fixed(.off)
        state.aspectRatio = .fixed(.square)
        state.timer = .fixed(.off)
        state.photoFormat = .fixed(.heif)
        let service = RecordingCameraService()
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, initialState: state) { captures.append($0) }
        let settings = model.settings
        #expect(settings.offeredSettings == [.live, .exposure])
        #expect(settings.topBarSettings == [.live])
        #expect(settings.offeredPhotoFormats.isEmpty)
        await model.start()
        #expect(settings.deliversPhotos(within: settings.output))
        #expect(settings.offeredPhotoFormats.isEmpty)
        #expect(settings.availablePhotoFormats == [.heif, .raw])
        await model.capture()
        let request = try #require(service.captureRequests.first)
        #expect(request.flashMode == .off)
        #expect(request.format == .heif)
        let capture = try #require(captures.first)
        #expect(try CaptureTestSupport.isSquare(capture))
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("Live Photo fixed on takes Live Photos without a control")
    func liveFixedOn() async throws {
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled = .fixed(true)
        let service = RecordingCameraService()
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, initialState: state) { captures.append($0) }
        #expect(model.settings.isLivePhotoOffered)
        #expect(model.settings.offeredSettings.contains(.live) == false)
        #expect(model.settings.topBarSettings == [.flash])
        await model.start()
        await model.capture()
        #expect(service.captureRequests.map(\.isLivePhotoEnabled) == [true])
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("With everything fixed the panel has no tile, the top bar no indicator and the exposure drag nothing to do")
    func nothingAdjustable() {
        var state = CameraFlowInitialState()
        state.flashMode = .fixed(.auto)
        state.aspectRatio = .fixed(.fourByThree)
        state.timer = .fixed(.off)
        state.exposureBias = .fixed(0)
        state.photoFormat = .fixed(.heif)
        let model = makeCaptureModel(service: RecordingCameraService(), initialState: state, isLivePhotoOffered: false)
        #expect(model.settings.offeredSettings.isEmpty)
        #expect(model.settings.topBarSettings.isEmpty)
        #expect(model.panel.settings.isEmpty)
        #expect(model.settings.isExposureAdjustable == false)
        let centre = CGPoint(x: 0.5, y: 0.5)
        #expect(model.beginExposureDrag(atUnitPoint: centre, devicePoint: centre) == false)
        #expect(model.focus.reticle == nil)
    }

    @Test("The format tile goes with a fixed format while the quality is fixed too, and stays with an adjustable one")
    func formatRows() async {
        var state = CameraFlowInitialState()
        state.photoFormat = .fixed(.heif)
        let fixedFormat = makeCaptureModel(service: RecordingCameraService(), initialState: state)
        #expect(fixedFormat.settings.offeredSettings.contains(.format) == false)
        #expect(fixedFormat.panel.settings.contains(.format) == false)
        #expect(fixedFormat.settings.changedSettings.isEmpty)
        let model = makeCaptureModel(service: RecordingCameraService(), initialState: CameraFlowInitialState())
        await model.start()
        #expect(model.settings.offeredSettings.contains(.format))
        #expect(model.settings.offeredPhotoFormats == [.heif, .raw])
        #expect(model.settings.effectivePhotoFrame?.isPreferred == true)
    }

    // MARK: - The output narrows what is offered

    @Test("A size limit below the camera's size leaves the size for the output to scale, and RAW out")
    func sizeLimit() async {
        var output = CameraFlowOutput()
        output.size = .longSide(maximum: 4032)
        let model = makeCaptureModel(service: RecordingCameraService(), output: output)
        await model.start()
        #expect(model.settings.deliversPhotos(within: model.settings.output))
        #expect(model.settings.effectivePhotoFrame?.isPreferred == true)
        #expect(model.settings.availablePhotoFormats == [.heif, .raw])

        output.size = .standard
        let scaledModel = makeCaptureModel(service: RecordingCameraService(), output: output)
        await scaledModel.start()
        #expect(scaledModel.settings.deliversPhotos(within: scaledModel.settings.output) == false)
        #expect(scaledModel.settings.effectivePhotoFrame?.isPreferred == true)
        #expect(scaledModel.settings.availablePhotoFormats == [.heif])
    }

    @Test(
        "A re-encoded or stripped output offers no RAW, and a RAW opening falls back to HEIF",
        arguments: [
            (CameraFlowOutputFormat.jpeg(quality: 0.8), CameraFlowOutputMetadata.kept),
            (.heic(quality: 0.8), .kept),
            (.original, .stripped)
        ]
    )
    func noRAW(format: CameraFlowOutputFormat, metadata: CameraFlowOutputMetadata) async throws {
        var output = CameraFlowOutput()
        output.format = format
        output.metadata = metadata
        var state = CameraFlowInitialState()
        state.photoFormat.value = .raw
        let service = RecordingCameraService()
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, initialState: state, output: output) { captures.append($0) }
        await model.start()
        #expect(model.settings.availablePhotoFormats == [.heif])
        #expect(model.settings.offeredPhotoFormats == [.heif])
        #expect(model.settings.effectivePhotoFormat == .heif)
        #expect(model.settings.isLivePhotoSelectable)
        await model.capture()
        #expect(service.captureRequests.map(\.format) == [.heif])
        try captures.forEach(CaptureTestSupport.discardFiles)
    }
}
