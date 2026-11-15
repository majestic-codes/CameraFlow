//
//  CameraFlowCompletionTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// A flow that ends by itself after one photo, from the camera or from the library, and one that waits for the
/// check mark as before.
@MainActor
@Suite("Ending after one photo", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraFlowCompletionTests {

    private func makeFlow(
        harness: FlowHarness,
        completion: CameraFlowCompletion = .afterOnePhoto,
        librarySaving: PhotoLibrarySavingModel? = nil
    ) -> TestFlowModel {
        var configuration = CameraFlowConfiguration()
        configuration.completion = completion
        return harness.makeFlow(
            limit: configuration.effectivePhotoLimit,
            librarySaving: librarySaving,
            completion: completion
        )
    }

    @Test("By default the flow waits for the check mark, with the app's limit")
    func confirmsByDefault() async {
        var configuration = CameraFlowConfiguration()
        configuration.photoLimit = .maximum(5)
        #expect(configuration.completion == .userConfirms)
        #expect(configuration.effectivePhotoLimit == .maximum(5))
        let harness = FlowHarness()
        let flow = makeFlow(harness: harness, completion: .userConfirms)
        await flow.camera.start()
        await flow.camera.capture()
        await settleQueuedWork()
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.photoSet.count == 1)
        flow.photoSet.discard()
    }

    @Test("Ending after one photo holds the set to one photo, whatever the app's limit")
    func limitOfOne() {
        var configuration = CameraFlowConfiguration()
        configuration.photoLimit = .maximum(5)
        configuration.completion = .afterOnePhoto
        #expect(configuration.effectivePhotoLimit == .maximum(1))
    }

    @Test("One shot is handed over by itself, without the review, and the camera closes")
    func cameraShot() async throws {
        let harness = FlowHarness()
        let flow = makeFlow(harness: harness)
        await flow.camera.start()
        await flow.camera.capture()
        await settle { harness.outcome.handedOver.count == 1 }
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.count == 1)
        #expect(handedOver.first?.source == .camera)
        #expect(handedOver.first?.markedUp?.url == nil)
        #expect(flow.mode == .shooting)
        #expect(flow.photoSet.hasEnded)
        #expect(flow.canShoot == false)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("One pick from the library is handed over by itself, and the picker offers one")
    func libraryPick() async throws {
        let harness = FlowHarness()
        let flow = makeFlow(harness: harness)
        await flow.camera.start()
        #expect(flow.librarySelectionLimit == 1)
        let data = try FlowTestSupport.makeJPEG()
        await flow.importPicks([FakeLibraryPick(data: data)])
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.count == 1)
        #expect(handedOver.first?.source == .photoLibrary)
        #expect(flow.photoSet.hasEnded)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A pick that cannot be loaded leaves the flow open with its notice")
    func failedPick() async {
        let harness = FlowHarness()
        let flow = makeFlow(harness: harness)
        await flow.camera.start()
        await flow.importPicks([FakeLibraryPick(data: nil)])
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.photoSet.notice == .importFailed(count: 1))
        #expect(flow.photoSet.hasEnded == false)
        flow.photoSet.discard()
    }

    @Test("A shot that fails leaves the flow open for another one")
    func failedShot() async {
        let harness = FlowHarness()
        let flow = makeFlow(harness: harness)
        await flow.camera.start()
        harness.service.captureError = .captureFailed("no photo")
        await flow.camera.capture()
        await settleQueuedWork()
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.canShoot)
        flow.photoSet.discard()
    }

    @Test("Ending after one photo waits for its save to the library and reports it")
    func waitsForSave() async throws {
        let harness = FlowHarness()
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        let saving = CaptureTestSupport.makeLibrarySaving(moment: .afterEachPhoto, writer: writer)
        let flow = makeFlow(harness: harness, librarySaving: saving)
        await flow.camera.start()
        await flow.camera.capture()
        await settle { harness.outcome.handedOver.count == 1 }
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [.saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1"))])
        #expect(writer.additions.count == 1)
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
