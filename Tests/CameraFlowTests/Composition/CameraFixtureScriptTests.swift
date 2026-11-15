//
//  CameraFixtureScriptTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Fixtures of the initial state", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraFixtureScriptTests {
    let service = RecordingCameraService()
    let clock = ManualClock()
    let files = CaptureTestSupport.makeFileStore()

    @Test("The automatic photos are taken once the camera has run for the delay")
    func automaticCaptures() async throws {
        var captures: [CameraCapture] = []
        var state = CameraFlowInitialState()
        state.automaticCaptureCount = 2
        let model = makeCaptureModel(service: service, initialState: state, clock: clock, files: files) {
            captures.append($0)
        }
        await model.start()
        let script = CameraFixtureScript(initialState: state, clock: clock)
        let playing = Task { await script.play(on: model) }
        await clock.waitForSleepers()
        #expect(service.captureRequests.isEmpty)
        clock.advance(by: CameraFixtureScript.automaticCaptureDelay)
        await playing.value
        #expect(model.shutter.captureCount == 2)
        #expect(captures.count == 2)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A screen that goes away during the delay takes no automatic photo")
    func cancelledBeforeAutomaticCaptures() async {
        var state = CameraFlowInitialState()
        state.automaticCaptureCount = 2
        let model = makeCaptureModel(service: service, initialState: state, clock: clock, files: files) { _ in
            Issue.record("Nothing is handed over")
        }
        let running = run(state, on: model)
        await clock.waitForSleepers()
        running.cancel()
        await running.value
        #expect(service.captureRequests.isEmpty)
        #expect(service.calls.last == .stop)
    }

    @Test("The dial fixture shows on a camera that has started")
    func dial() async {
        var state = CameraFlowInitialState()
        state.isZoomDialOpen = true
        let model = makeCaptureModel(service: service, initialState: state, clock: clock, files: files)
        let running = run(state, on: model)
        await settle { model.zoom.isDialOpen }
        #expect(model.focus.reticle == nil)
        #expect(service.captureRequests.isEmpty)
        running.cancel()
        await running.value
    }

    /// Runs a camera with the fixtures of a state until the returned task is cancelled.
    private func run(_ state: CameraFlowInitialState, on model: PhotoCameraModel) -> Task<Void, Never> {
        let script = CameraFixtureScript(initialState: state, clock: clock)
        return Task { await CameraScreenLifetime.run(model, script: script) }
    }
}
