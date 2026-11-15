//
//  DualCameraSavingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

@MainActor
@Suite(
    "Dual camera: saving to the photo library and the output of the set",
    .temporaryDirectory,
    .timeLimit(.minutes(1))
)
struct DualCameraSavingTests {
    private let harness = FlowHarness()
    private let writer = FakePhotoLibraryWriter()

    /// A flow with the circle on whose camera took one photo, saved to the library while saving is on, when the set is
    /// accepted unless the test says otherwise.
    private func makeFlowWithDualPhoto(
        output: CameraFlowOutput = CameraFlowOutput(),
        isSaving: Bool = true,
        moment: CameraFlowPhotoLibrarySaving.Moment = .whenSetAccepted
    ) async -> (TestFlowModel, PhotoLibrarySavingModel) {
        let saving = CaptureTestSupport.makeLibrarySaving(isOn: isSaving, moment: moment, writer: writer)
        let flow = harness.makeFlow(
            initialState: DualCameraFixture.keptState,
            isDualCameraOffered: true,
            output: output,
            librarySaving: saving
        )
        flow.camera.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await flow.camera.start()
        await flow.camera.toggleDualCamera()
        await flow.camera.capture()
        return (flow, saving)
    }

    @Test("The library gets the copy with the circle, and the app the same copy as the edited one")
    func savesCopy() async throws {
        let (flow, _) = await makeFlowWithDualPhoto()
        await flow.accept()
        let photo = try #require(harness.outcome.handedOver.first?.first)
        let copyURL = try #require(photo.markedUp?.url)
        #expect(writer.additions.map(\.entry.photoFileURL) == [copyURL])
        #expect(photo.photoLibrarySave == .saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")))
        #expect(photo.original.url != copyURL)
        try FlowTestSupport.discardFiles(of: [photo])
    }

    @Test("A photo with the circle saved after its shot misses nothing: the library has its copy with the circle")
    func circleSavedAfterShot() async throws {
        let (flow, _) = await makeFlowWithDualPhoto(moment: .afterEachPhoto)
        await settle { flow.photoSet.shutterSaves.results.count == 1 }
        await flow.accept()
        let photo = try #require(harness.outcome.handedOver.first?.first)
        let copyURL = try #require(photo.markedUp?.url)
        #expect(writer.additions.map(\.entry.photoFileURL) == [copyURL])
        #expect(photo.photoLibrarySave == .saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")))
        try FlowTestSupport.discardFiles(of: [photo])
    }

    @Test("Under an output the library gets the full copy, which goes once saved, and the app the copy of the output")
    func savesFullCopyUnderOutput() async throws {
        var output = CameraFlowOutput()
        output.format = .jpeg(quality: 0.8)
        let (flow, _) = await makeFlowWithDualPhoto(output: output)
        #expect(writer.additions.isEmpty)
        await flow.accept()
        let saved = try #require(writer.additions.first?.entry.photoFileURL)
        #expect(saved.lastPathComponent.contains("-dual-"))
        #expect(FlowTestSupport.fileExists(saved) == false)
        let photo = try #require(harness.outcome.handedOver.first?.first)
        let copyURL = try #require(photo.markedUp?.url)
        #expect(try ImageFile.contentType(of: copyURL) == .jpeg)
        #expect(try ImageFile.contentType(of: photo.original.url) == .jpeg)
        try FlowTestSupport.discardFiles(of: [photo])
    }

    @Test("Without saving the full copy goes at the check mark, and nothing reaches the library")
    func noSaving() async throws {
        var output = CameraFlowOutput()
        output.format = .jpeg(quality: 0.8)
        let (flow, _) = await makeFlowWithDualPhoto(output: output, isSaving: false)
        #expect(flow.photoSet.photos.first?.libraryFileURL != nil)
        await flow.accept()
        #expect(writer.additions.isEmpty)
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [nil])
        let names = try FileManager.default.contentsOfDirectory(atPath: harness.files.directory.path)
        #expect(names.count == 2, "Files: \(names)")
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A drawing goes over the full copy with the circle, and its copy is written in the output")
    func drawingUnderOutput() async throws {
        var output = CameraFlowOutput()
        output.format = .heic(quality: 0.6)
        let (flow, _) = await makeFlowWithDualPhoto(output: output)
        let circleCopy = try #require(flow.photoSet.photos.first?.dualCameraCopy?.url)
        let fullCopy = try #require(flow.photoSet.photos.first?.libraryFileURL)
        let photoIdentifier = try #require(flow.photoSet.photos.first?.id)
        let drawing = try FlowTestSupport.makeDrawing("over the circle")
        flow.photoSet.setDrawing(drawing, ofPhoto: photoIdentifier)
        await flow.accept()
        #expect(await harness.renderer.copiedPhotoURLs == [fullCopy, fullCopy])
        #expect(await harness.renderer.copyOutputs == [output, CameraFlowOutput()])
        let photo = try #require(harness.outcome.handedOver.first?.first)
        #expect(photo.markedUp?.url != nil)
        #expect(FlowTestSupport.fileExists(circleCopy) == false)
        #expect(writer.additions.count == 1)
        try FlowTestSupport.discardFiles(of: [photo])
    }
}
