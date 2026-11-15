//
//  CameraScreenLifetimeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@MainActor
@Suite("The life of the camera screen, tied to the task of its view", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraScreenLifetimeTests {
    let service = RecordingCameraService()
    let clock = ManualClock()

    @Test("Running the camera stops it when the task is cancelled")
    func runUntilCancelled() async {
        let model = makeCaptureModel(service: service, clock: clock)
        let script = CameraFixtureScript(initialState: CameraFlowInitialState(), clock: clock)
        let running = Task { await CameraScreenLifetime.run(model, script: script) }
        await settle { model.session.capabilities != nil }
        running.cancel()
        await running.value
        #expect(service.calls == [.start(.back), .exposureBias(0), .stop])
    }

    @Test("A run cancelled before the camera starts never starts it")
    func runCancelledEarly() async {
        let model = makeCaptureModel(service: service, clock: clock)
        let script = CameraFixtureScript(initialState: CameraFlowInitialState(), clock: clock)
        let running = Task { await CameraScreenLifetime.run(model, script: script) }
        running.cancel()
        await running.value
        #expect(service.calls == [.stop])
    }

    @Test("A view that goes away while the set is handed over does not take the set with it")
    func viewGoneMeanwhile() async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(gate: gate)
        let harness = FlowHarness()
        let flow = harness.makeFlow(librarySaving: CaptureTestSupport.makeLibrarySaving(writer: writer))
        let script = CameraFixtureScript(initialState: CameraFlowInitialState())
        let view = Task { await CameraScreenLifetime.run(flow, script: script) }
        await settle { flow.camera.session.capabilities != nil }
        await flow.camera.capture()
        let handingOver = Task { await flow.accept() }
        await gate.arrival()
        view.cancel()
        await view.value
        #expect(flow.camera.delivery.isClosed)
        #expect(harness.outcome.handedOver.isEmpty)
        await gate.open()
        await handingOver.value
        try #require(harness.outcome.handedOver.count == 1)
        let handedOver = harness.outcome.handedOver[0]
        #expect(handedOver.map(\.photoLibrarySave) == [.saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1"))])
        #expect(handedOver.flatMap(\.fileURLs).allSatisfy(FlowTestSupport.fileExists))
        #expect(harness.outcome.exitCount == 0)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A view that goes away with a set nobody accepted deletes the set and tells the app nothing")
    func viewGoneWithOpenSet() async throws {
        let harness = FlowHarness()
        let flow = harness.makeFlow()
        let script = CameraFixtureScript(initialState: CameraFlowInitialState())
        let view = Task { await CameraScreenLifetime.run(flow, script: script) }
        await settle { flow.camera.session.capabilities != nil }
        await flow.camera.capture()
        let photos = flow.photoSet.photos
        view.cancel()
        await view.value
        #expect(flow.photoSet.hasEnded)
        expectDeleted(photos)
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(harness.outcome.exitCount == 0)
    }
}
