//
//  LivePhotoAvailabilityTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Live Photo on the screen or not", .temporaryDirectory, .timeLimit(.minutes(1)))
struct LivePhotoAvailabilityTests {
    let service = RecordingCameraService()

    @Test("A screen with Live Photo has every tile in the stock order")
    func tilesWithLivePhoto() {
        let model = makeCaptureModel(service: service, isLivePhotoOffered: true)
        #expect(model.settings.offeredSettings == [.flash, .live, .aspect, .timer, .exposure, .format])
        #expect(model.panel.settings == model.settings.offeredSettings)
    }

    @Test("A screen without Live Photo has no Live tile")
    func tilesWithoutLivePhoto() {
        let model = makeCaptureModel(service: service, isLivePhotoOffered: false)
        #expect(model.settings.offeredSettings == [.flash, .aspect, .timer, .exposure, .format])
        #expect(model.panel.settings == model.settings.offeredSettings)
    }

    @Test("A screen without Live Photo never has it available, whatever the camera supports")
    func neverAvailable() async {
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled.value = true
        let model = makeCaptureModel(service: service, initialState: state, isLivePhotoOffered: false)
        await model.start()
        #expect(service.photoCapabilities?.isLivePhotoSupported == true)
        #expect(model.settings.isLivePhotoEnabled == false)
        #expect(model.settings.isLivePhotoAvailable == false)
        #expect(model.settings.isLivePhotoSelectable == false)
        #expect(model.settings.isLivePhotoInEffect == false)
    }

    @Test(
        "A screen without Live Photo takes every photo as a still one",
        arguments: [CameraFlowPhotoFormat.heif, .raw]
    )
    func stillCaptures(format: CameraFlowPhotoFormat) async throws {
        var captures: [CameraCapture] = []
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled.value = true
        state.photoFormat.value = format
        let model = makeCaptureModel(service: service, initialState: state, isLivePhotoOffered: false) {
            captures.append($0)
        }
        await model.start()
        await model.capture()
        await model.capture()
        #expect(model.notices.captureError == nil)
        #expect(service.captureRequests.map(\.isLivePhotoEnabled) == [false, false])
        #expect(captures.count == 2)
        #expect(captures.allSatisfy { $0.livePhotoMovieURL == nil })
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("The same initial state takes a Live Photo on a screen that has it")
    func liveCapture() async throws {
        var captures: [CameraCapture] = []
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled.value = true
        let model = makeCaptureModel(service: service, initialState: state, isLivePhotoOffered: true) {
            captures.append($0)
        }
        await model.start()
        await model.capture()
        let capture = try #require(captures.first)
        #expect(capture.livePhotoMovieURL != nil)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("The panel opens the sub-panel of any setting it has a tile for")
    func subPanelOfATile() {
        let model = makeCaptureModel(service: service, isLivePhotoOffered: false)
        for setting in model.panel.settings {
            model.panel.showSubPanel(setting)
            #expect(model.panel.presentation == .subPanel(setting))
        }
    }
}
