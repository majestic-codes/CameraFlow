//
//  CameraFlowPhotoLibrarySaveOrderTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// The saves to the photo library one after the other: the album one save creates is the album the next finds, so
/// quick shots into a new album make one album.
@MainActor
@Suite("Saves to the photo library in turn", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraFlowPhotoLibrarySaveOrderTests {

    @Test("A save after a shot reaches the library only once the save before it has ended")
    func savesInTurn() async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(authorization: .authorized, gate: gate)
        let saving = CaptureTestSupport.makeLibrarySaving(
            destination: .album(named: "Field"),
            moment: .afterEachPhoto,
            writer: writer
        )
        let harness = FlowHarness()
        let flow = harness.makeFlow(librarySaving: saving)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        await gate.arrival()
        await settleQueuedWork()
        #expect(await gate.arrivalCount == 1)
        await gate.open()
        await settle { flow.photoSet.shutterSaves.results.count == 2 }
        #expect(await gate.arrivalCount == 2)
        #expect(writer.additions.map(\.albumName) == ["Field", "Field"])
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("The saves of the check mark keep the order of the set")
    func checkMarkInOrder() async throws {
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let harness = FlowHarness()
        let flow = harness.makeFlow(librarySaving: saving)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(writer.additions.map(\.entry.photoFileURL) == handedOver.map(\.original.url))
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
