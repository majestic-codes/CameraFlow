//
//  PhotoSetLifetimeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite(
    "Photo set: a set that is discarded during the hand-over",
    .temporaryDirectory,
    .timeLimit(.minutes(1))
)
struct PhotoSetLifetimeTests {

    @Test("A set that is discarded while its copies are written is handed over all the same, once, with its files")
    func discardedMeanwhile() async throws {
        let gate = CallGate()
        let harness = FlowHarness(renderer: RecordingMarkupRenderer(gate: gate))
        let flow = try await harness.makeStartedFlow(photoCount: 2, drawnIndices: [0, 1])
        let photos = flow.photoSet.photos
        let handingOver = Task { await flow.accept() }
        await gate.arrival()
        flow.photoSet.discard()
        #expect(flow.photoSet.hasEnded == false)
        await gate.open()
        await handingOver.value
        flow.photoSet.discard()
        try #require(harness.outcome.handedOver.count == 1)
        let handedOver = harness.outcome.handedOver[0]
        #expect(handedOver.map(\.id) == photos.map(\.id))
        #expect(handedOver.flatMap(\.fileURLs).count == 4)
        #expect(handedOver.flatMap(\.fileURLs).allSatisfy(FlowTestSupport.fileExists))
        #expect(flow.photoSet.hasEnded)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A set that is discarded while a hand-over fails is discarded once the hand-over has failed")
    func discardedWhileHandOverFails() async throws {
        let gate = CallGate()
        let harness = FlowHarness(renderer: RecordingMarkupRenderer(gate: gate))
        let flow = try await harness.makeStartedFlow(photoCount: 2, drawnIndices: [0, 1])
        let photos = flow.photoSet.photos
        await harness.renderer.failCopy(number: 1)
        let handingOver = Task { await flow.accept() }
        await gate.arrival()
        flow.photoSet.discard()
        await gate.open()
        await handingOver.value
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(await harness.renderer.copiedPhotoURLs.count == 1)
        #expect(flow.photoSet.hasEnded)
        #expect(flow.photoSet.notice == nil)
        expectDeleted(photos)
        #expect(FlowTestSupport.fileExists(harness.files.directory) == false)
    }

    @Test("A set that is discarded while its photos are saved to the library is handed over with every save")
    func discardedWhileSaving() async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(gate: gate)
        let harness = FlowHarness()
        let flow = harness.makeFlow(librarySaving: CaptureTestSupport.makeLibrarySaving(writer: writer))
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        let handingOver = Task { await flow.accept() }
        await gate.arrival()
        flow.photoSet.discard()
        await gate.open()
        await handingOver.value
        try #require(harness.outcome.handedOver.count == 1)
        let handedOver = harness.outcome.handedOver[0]
        #expect(writer.additions.count == 2)
        let first = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")
        let second = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-2")
        let saves: [CameraFlowPhotoLibrarySave] = [.saved(first), .saved(second)]
        #expect(handedOver.map(\.photoLibrarySave) == saves)
        #expect(handedOver.flatMap(\.fileURLs).allSatisfy(FlowTestSupport.fileExists))
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
