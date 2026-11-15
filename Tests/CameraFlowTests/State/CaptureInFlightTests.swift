//
//  CaptureInFlightTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("A capture in flight when its session goes", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CaptureInFlightTests {
    /// What takes the session away under a capture. A flip and a switch of the circle wait for the capture instead
    /// (`CameraChangeUnderCaptureTests`).
    enum SessionEnd: Sendable, CaseIterable {
        case stopped
        case failed
        case failedAndRestarted
    }

    private func end(_ sessionEnd: SessionEnd, of model: PhotoCameraModel, service: RecordingCameraService) async {
        switch sessionEnd {
        case .stopped: model.stop()
        case .failed: await service.simulate(.runtimeError(.hardwareFault))
        case .failedAndRestarted: await service.simulate(.runtimeError(.mediaServicesReset))
        }
    }

    @Test("The capture fails, the shutter is free again and no photo is handed over", arguments: SessionEnd.allCases)
    func captureEnds(sessionEnd: SessionEnd) async {
        let service = RecordingCameraService()
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, isDualCameraOffered: true) { captures.append($0) }
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await model.start()
        service.holdsCalls = true
        let capturing = Task { await model.capture() }
        await settle { service.heldCallCount == 1 }
        #expect(model.shutter.isCapturing)
        service.holdsCalls = false
        await end(sessionEnd, of: model, service: service)
        await capturing.value
        #expect(model.shutter.isCapturing == false)
        #expect(captures.isEmpty)
        #expect(service.captureRequests.count == 1)
        // A camera that starts again clears what the capture said.
        if [.stopped, .failed].contains(sessionEnd) {
            #expect(model.notices.captureError == .notRunning)
        }
        model.close()
    }

    @Test("The next capture of a camera that runs again is taken")
    func nextCapture() async throws {
        let service = RecordingCameraService()
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service) { captures.append($0) }
        await model.start()
        service.holdsCalls = true
        let capturing = Task { await model.capture() }
        await settle { service.heldCallCount == 1 }
        service.holdsCalls = false
        model.stop()
        await capturing.value
        await model.resume()
        await model.capture()
        #expect(model.notices.captureError == nil)
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }
}
