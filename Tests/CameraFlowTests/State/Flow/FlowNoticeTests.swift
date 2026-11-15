//
//  FlowNoticeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("The one thing the flow says over the viewfinder", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FlowNoticeTests {

    @Test("In the shooting mode the camera speaks first, and the set when the camera has nothing to say")
    func shooting() async throws {
        let harness = FlowHarness()
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        #expect(flow.notice == nil)
        await flow.photoSet.importPicks([FakeLibraryPick(data: nil)])
        #expect(flow.notice == .photoSet(.importFailed(count: 1)))
        await harness.service.simulate(.interrupted(.cameraInUseByAnotherClient))
        #expect(flow.notice == .camera(.interrupted(.cameraInUseByAnotherClient)))
        await harness.service.simulate(.interruptionEnded)
        #expect(flow.notice == .photoSet(.importFailed(count: 1)))
        flow.photoSet.discard()
    }

    @Test("In the review the camera is not heard: the drawing mode speaks first, then the set")
    func review() async throws {
        let harness = FlowHarness()
        let flow = try await harness.makeReviewedFlow(photoCount: 1)
        flow.camera.notices.captureFailed(with: .notRunning)
        #expect(flow.notice == nil)
        harness.canvasOpener.failure = .engineUnavailable(.paperKit)
        await flow.startMarkup()
        #expect(flow.notice == .markup(.cannotOpen))
        flow.photoSet.discard()
    }

    @Test("Picks and the check mark clear what the camera said")
    func flowActionsClearTheCamera() async throws {
        let harness = FlowHarness()
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        flow.camera.notices.captureFailed(with: .notRunning)
        await flow.importPicks([])
        #expect(flow.camera.notice == nil)
        flow.camera.notices.showDualCameraNotice(.unavailable)
        await flow.accept()
        #expect(flow.camera.notice == nil)
        let handedOver = try #require(harness.outcome.handedOver.first)
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
