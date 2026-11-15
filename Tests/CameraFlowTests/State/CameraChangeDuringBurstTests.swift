//
//  CameraChangeDuringBurstTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// A change of the camera asked for while several photos are on their way: it waits for every one of them, as it
/// waits for one, and a tap meanwhile takes its photo with the camera that comes.
@MainActor
@Suite("A change of the camera during a burst", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraChangeDuringBurstTests {
    let service = RecordingCameraService()

    /// What changes the camera.
    enum CameraChange: Sendable, CaseIterable {
        case flip
        case dualCameraSwitch
    }

    private func change(_ change: CameraChange, of model: PhotoCameraModel) async {
        switch change {
        case .flip: await model.flipCamera()
        case .dualCameraSwitch: await model.toggleDualCamera()
        }
    }

    /// The start the change makes from the back camera alone.
    private func start(of change: CameraChange) -> RecordingCameraService.Call {
        switch change {
        case .flip: .start(.front)
        case .dualCameraSwitch: .startDualCamera(main: .back)
        }
    }

    @Test(
        "A change waits for every photo on its way, and a tap meanwhile takes its photo with the camera that comes",
        arguments: CameraChange.allCases
    )
    func changeDuringBurst(change: CameraChange) async throws {
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, isDualCameraOffered: true) { captures.append($0) }
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await model.start()
        service.holdsCalls = true
        let first = Task { await model.capture() }
        await settle { service.heldCallCount == 1 }
        let second = Task { await model.capture() }
        await settle { service.heldCallCount == 2 }
        let before = service.calls.count
        let changing = Task { await self.change(change, of: model) }
        await settleQueuedWork()
        #expect(model.changes.isChanging)
        let third = Task { await model.capture() }
        await settleQueuedWork()
        #expect(service.calls(after: before).isEmpty)
        service.holdsCalls = false
        await service.releaseHeldCaptures(inTurn: 2)
        await first.value
        await second.value
        await changing.value
        await third.value
        let later = service.calls(after: before)
        let startIndex = try #require(later.firstIndex(of: start(of: change)))
        let captureIndex = try #require(later.firstIndex { call in
            if case .capture = call { true } else { false }
        })
        #expect(startIndex < captureIndex)
        #expect(captures.count == 3)
        #expect(captures.map { $0.dualCameraCopy != nil } == [false, false, change == .dualCameraSwitch])
        #expect(model.session.position == (change == .flip ? .front : .back))
        #expect(model.notices.captureError == nil)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }
}
