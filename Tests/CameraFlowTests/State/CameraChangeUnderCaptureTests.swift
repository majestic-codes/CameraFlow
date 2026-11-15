//
//  CameraChangeUnderCaptureTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// A change of the camera and a photo in flight, as the stock camera keeps them apart: the change waits for the
/// photo the shutter fired, and a shutter pressed during a change takes its photo with the camera that comes.
@MainActor
@Suite("A change of the camera and a photo in flight", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraChangeUnderCaptureTests {
    let service = RecordingCameraService()

    /// What changes the camera.
    enum CameraChange: Sendable, CaseIterable {
        case flip
        case dualCameraSwitch
        case pressure
    }

    private func makeModel(
        initialState: CameraFlowInitialState = CameraFlowInitialState(),
        onCapture: @escaping (CameraCapture) -> Void
    ) -> PhotoCameraModel {
        let model = makeCaptureModel(
            service: service,
            initialState: initialState,
            isDualCameraOffered: true,
            onCapture: onCapture
        )
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        return model
    }

    private func change(_ change: CameraChange, of model: PhotoCameraModel) async {
        switch change {
        case .flip: await model.flipCamera()
        case .dualCameraSwitch: await model.toggleDualCamera()
        case .pressure: await model.dualCameraUnderPressure()
        }
    }

    /// The start the change makes of a camera, alone or as the pair, from the back camera alone or the pair.
    private func start(of change: CameraChange) -> RecordingCameraService.Call {
        switch change {
        case .flip: .start(.front)
        case .dualCameraSwitch: .startDualCamera(main: .back)
        case .pressure: .start(.back)
        }
    }

    @Test(
        "A change asked for while a photo is taken waits for it: the photo is handed over, then the camera changes",
        arguments: CameraChange.allCases
    )
    func changeWaitsForPhoto(change: CameraChange) async throws {
        var captures: [CameraCapture] = []
        let model = makeModel { captures.append($0) }
        await model.start()
        if change == .pressure {
            await model.toggleDualCamera()
        }
        service.holdsCalls = true
        let capturing = Task { await model.capture() }
        await settle { service.heldCallCount == 1 }
        service.holdsCalls = false
        let before = service.calls.count
        let changing = Task { await self.change(change, of: model) }
        await settleQueuedWork()
        #expect(service.calls(after: before).isEmpty)
        #expect(model.changes.isChanging)
        service.releaseHeldCalls()
        await capturing.value
        await changing.value
        #expect(captures.count == 1)
        #expect(model.notices.captureError == nil)
        #expect(service.calls(after: before).first == start(of: change))
        #expect(model.changes.isChanging == false)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A second tap of the flip while the first waits for a photo is ignored")
    func secondFlipWhileWaiting() async throws {
        var captures: [CameraCapture] = []
        let model = makeModel { captures.append($0) }
        await model.start()
        service.holdsCalls = true
        let capturing = Task { await model.capture() }
        await settle { service.heldCallCount == 1 }
        service.holdsCalls = false
        let flipping = Task { await model.flipCamera() }
        await settleQueuedWork()
        await model.flipCamera()
        service.releaseHeldCalls()
        await capturing.value
        await flipping.value
        #expect(service.calls.count { $0 == .start(.front) } == 1)
        #expect(model.session.position == .front)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A shutter pressed while the camera flips takes its photo with the camera it flips to, once it runs")
    func photoWaitsForFlip() async throws {
        var state = CameraFlowInitialState()
        state.photoFormat = CameraFlowSetting(.raw)
        var captures: [CameraCapture] = []
        let model = makeModel(initialState: state) { captures.append($0) }
        await model.start()
        service.holdsCalls = true
        let flipping = Task { await model.flipCamera() }
        await settle { service.heldCallCount == 1 }
        let capturing = Task { await model.capture() }
        await settleQueuedWork()
        #expect(service.captureRequests.isEmpty)
        #expect(model.shutter.captureCount == 0)
        service.holdsCalls = false
        service.releaseHeldCalls()
        await flipping.value
        await capturing.value
        let request = try #require(service.captureRequests.first)
        #expect(request.format == .heif)
        #expect(model.session.position == .front)
        #expect(model.notices.captureError == nil)
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A shutter pressed while the circle comes on takes its photo with the circle, once the pair runs")
    func photoWaitsForDualCamera() async throws {
        var captures: [CameraCapture] = []
        let model = makeModel { captures.append($0) }
        await model.start()
        service.holdsCalls = true
        let switching = Task { await model.toggleDualCamera() }
        await settle { service.heldCallCount == 1 }
        let capturing = Task { await model.capture() }
        await settleQueuedWork()
        #expect(service.captureRequests.isEmpty)
        service.holdsCalls = false
        service.releaseHeldCalls()
        await switching.value
        await capturing.value
        #expect(model.notices.captureError == nil)
        let capture = try #require(captures.first)
        #expect(capture.dualCameraCopy != nil)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }
}
