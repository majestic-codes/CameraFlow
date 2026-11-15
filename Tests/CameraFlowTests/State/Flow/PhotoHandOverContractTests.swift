//
//  PhotoHandOverContractTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// What the app owns after the check mark: the files of the photos it receives and nothing else. The finished
/// picture is the copy with the drawing where there is one, and no file the flow made on the way is left beside
/// them.
@MainActor
@Suite("The files the app receives", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoHandOverContractTests {
    private static var reencodingOutput: CameraFlowOutput {
        var output = CameraFlowOutput()
        output.format = .jpeg(quality: 0.6)
        return output
    }

    private func filesInDirectory(of harness: FlowHarness) throws -> Set<URL> {
        let contents = try FileManager.default.contentsOfDirectory(
            at: harness.files.directory,
            includingPropertiesForKeys: nil
        )
        return Set(contents.map(\.standardizedFileURL))
    }

    private func handedOverFiles(_ photos: [CameraFlowPhoto]) -> Set<URL> {
        let urls = photos.flatMap { [$0.original.url, $0.livePhotoMovieURL, $0.markedUp?.url].compactMap(\.self) }
        return Set(urls.map(\.standardizedFileURL))
    }

    @Test(
        "The directory holds exactly the files handed over, with and without a drawing, for both saving moments",
        arguments: [CameraFlowPhotoLibrarySaving.Moment.whenSetAccepted, .afterEachPhoto]
    )
    func onlyHandedOverFilesRemain(moment: CameraFlowPhotoLibrarySaving.Moment) async throws {
        let harness = FlowHarness()
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        let saving = CaptureTestSupport.makeLibrarySaving(moment: moment, writer: writer)
        let flow = harness.makeFlow(output: Self.reencodingOutput, librarySaving: saving)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        let drawn = try #require(flow.photoSet.photos.first)
        #expect(drawn.libraryFileURL != nil)
        flow.photoSet.setDrawing(try FlowTestSupport.makeDrawing(), ofPhoto: drawn.id)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(try filesInDirectory(of: harness) == handedOverFiles(handedOver))
        let drawnAsset = CameraFlowPhotoLibraryAsset(
            localIdentifier: "asset-1",
            isMissingDrawing: moment == .afterEachPhoto
        )
        let expectedSaves: [CameraFlowPhotoLibrarySave?] = [
            .saved(drawnAsset),
            .saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-2"))
        ]
        #expect(handedOver.map(\.photoLibrarySave) == expectedSaves)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A photo with a drawing gives the copy with it as its result, and one without gives its original")
    func resultFile() async throws {
        let harness = FlowHarness()
        let flow = harness.makeFlow()
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        let drawn = try #require(flow.photoSet.photos.first)
        flow.photoSet.setDrawing(try FlowTestSupport.makeDrawing(), ofPhoto: drawn.id)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        try #require(handedOver.count == 2)
        let markedUp = try #require(handedOver[0].markedUp?.url)
        #expect(handedOver[0].result.url == markedUp)
        #expect(markedUp != handedOver[0].original.url)
        #expect(FlowTestSupport.fileExists(handedOver[0].original.url))
        #expect(handedOver[1].markedUp?.url == nil)
        #expect(handedOver[1].result.url == handedOver[1].original.url)
        #expect(handedOver.allSatisfy { $0.photoLibrarySave == nil })
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("The files the app received outlast the flow: nothing deletes them after the hand-over")
    func filesOutlastFlow() async throws {
        let harness = FlowHarness()
        let flow = harness.makeFlow()
        await flow.camera.start()
        await flow.camera.capture()
        await flow.accept()
        flow.photoSet.discard()
        flow.camera.close()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.allSatisfy { FlowTestSupport.fileExists($0.original.url) })
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
