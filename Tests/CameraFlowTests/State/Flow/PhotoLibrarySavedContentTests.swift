//
//  PhotoLibrarySavedContentTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Saving to the photo library: what is saved", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoLibrarySavedContentTests {
    // MARK: - What is saved

    @Test("A photo picked from the library is never saved, drawn on or not")
    func libraryPhotoIsNotSaved() async throws {
        let writer = FakePhotoLibraryWriter()
        let (harness, flow) = makeSavingFlow(writer: writer)
        await flow.camera.start()
        try await harness.importLibraryPhoto(into: flow)
        let photoIdentifier = try #require(flow.photoSet.photos.first?.id)
        flow.photoSet.setDrawing(try FlowTestSupport.makeDrawing("on a library photo"), ofPhoto: photoIdentifier)
        await flow.accept()
        #expect(writer.additions.isEmpty)
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [nil])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A photo with a drawing is one asset: the original, and the copy with the drawing as its edit")
    func markedUpPhoto() async throws {
        let writer = FakePhotoLibraryWriter()
        let (harness, flow) = makeSavingFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        let photos = flow.photoSet.photos
        try #require(photos.count == 2)
        flow.photoSet.setDrawing(try FlowTestSupport.makeDrawing("circled"), ofPhoto: photos[0].id)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        try #require(handedOver.count == 2)
        let markedUpURL = try #require(handedOver[0].markedUp?.url)
        try #require(writer.additions.count == 2)
        #expect(writer.additions[0].entry.photoFileURL == handedOver[0].original.url)
        #expect(writer.additions[0].entry.markedUpFileURL == markedUpURL)
        #expect(writer.additions[1].entry.markedUpFileURL == nil)
        let saves = handedOver.map(\.photoLibrarySave)
        let first = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")
        let second = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-2")
        #expect(saves == [.saved(first), .saved(second)])
        #expect(await harness.renderer.copiedPhotoURLs == [photos[0].fileURL])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A drawing Photos did not take leaves the photo in the library without it, and only that asset says so")
    func drawingNotTaken() async throws {
        let writer = FakePhotoLibraryWriter()
        writer.dropDrawings()
        let (harness, flow) = makeSavingFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        let photos = flow.photoSet.photos
        try #require(photos.count == 2)
        flow.photoSet.setDrawing(try FlowTestSupport.makeDrawing("circled"), ofPhoto: photos[0].id)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        try #require(handedOver.count == 2)
        #expect(handedOver[0].markedUp != nil)
        let drawn = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1", isMissingDrawing: true)
        let plain = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-2")
        #expect(handedOver.map(\.photoLibrarySave) == [.saved(drawn), .saved(plain)])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A Live Photo goes in with its movie, and without it once a drawing is on it")
    func livePhoto() async throws {
        let writer = FakePhotoLibraryWriter()
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled = CameraFlowSetting(true)
        let harness = FlowHarness()
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let flow = harness.makeFlow(initialState: state, librarySaving: saving)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        let photos = flow.photoSet.photos
        try #require(photos.count == 2)
        flow.photoSet.setDrawing(try FlowTestSupport.makeDrawing("on the second"), ofPhoto: photos[1].id)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        try #require(handedOver.count == 2)
        try #require(writer.additions.count == 2)
        #expect(writer.additions[0].entry.livePhotoMovieURL == handedOver[0].livePhotoMovieURL)
        #expect(writer.additions[0].entry.livePhotoMovieURL != nil)
        #expect(writer.additions[1].entry.livePhotoMovieURL == nil)
        #expect(writer.additions[1].entry.markedUpFileURL != nil)
        #expect(handedOver[1].livePhotoMovieURL != nil)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("Under an output that changes the file, the library gets the camera's photo and the app the output")
    func cameraFileForTheLibrary() async throws {
        let writer = FakePhotoLibraryWriter()
        var output = CameraFlowOutput()
        output.format = .jpeg(quality: 0.8)
        let service = RecordingCameraService(backPhotoCapabilities: SimulatedCameraService.iPhoneBackPhotoCapabilities)
        let harness = FlowHarness(service: service)
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let flow = harness.makeFlow(output: output, librarySaving: saving)
        await flow.camera.start()
        await flow.camera.capture()
        let libraryURL = try #require(flow.photoSet.photos.first?.libraryFileURL)
        await flow.accept()
        let addition = try #require(writer.additions.first)
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(addition.entry.photoFileURL == libraryURL)
        #expect(addition.entry.photoFileURL.lastPathComponent.hasSuffix("-camera.heic"))
        #expect(handedOver.map(\.original.contentType) == [.jpeg])
        #expect(FlowTestSupport.fileExists(libraryURL) == false)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("Under an output that changes the file, both copies of the drawing are made from the camera's full picture")
    func markedUpUnderOutput() async throws {
        let writer = FakePhotoLibraryWriter()
        var output = CameraFlowOutput()
        output.format = .jpeg(quality: 0.8)
        let service = RecordingCameraService(backPhotoCapabilities: SimulatedCameraService.iPhoneBackPhotoCapabilities)
        let harness = FlowHarness(service: service)
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let flow = harness.makeFlow(output: output, librarySaving: saving)
        await flow.camera.start()
        await flow.camera.capture()
        let photo = try #require(flow.photoSet.photos.first)
        let libraryURL = try #require(photo.libraryFileURL)
        flow.photoSet.setDrawing(try FlowTestSupport.makeDrawing("over the full picture"), ofPhoto: photo.id)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        try #require(handedOver.count == 1)
        let addition = try #require(writer.additions.first)
        #expect(await harness.renderer.copiedPhotoURLs == [libraryURL, libraryURL])
        #expect(await harness.renderer.copyOutputs == [output, CameraFlowOutput()])
        let editedURL = try #require(addition.entry.markedUpFileURL)
        #expect(editedURL != handedOver[0].markedUp?.url)
        #expect(FlowTestSupport.fileExists(editedURL) == false)
        #expect(FlowTestSupport.fileExists(try #require(handedOver[0].markedUp?.url)))
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A drawing that cannot be rendered for the library leaves the photo unsaved and says why, until it can")
    func drawingNotWrittenForTheLibrary() async throws {
        let writer = FakePhotoLibraryWriter()
        var output = CameraFlowOutput()
        output.format = .jpeg(quality: 0.8)
        let service = RecordingCameraService(backPhotoCapabilities: SimulatedCameraService.iPhoneBackPhotoCapabilities)
        let harness = FlowHarness(service: service)
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let flow = harness.makeFlow(output: output, librarySaving: saving)
        await flow.camera.start()
        await flow.camera.capture()
        let photo = try #require(flow.photoSet.photos.first)
        flow.photoSet.setDrawing(try FlowTestSupport.makeDrawing("not for the library"), ofPhoto: photo.id)
        await harness.renderer.failCopy(number: 2)
        await flow.accept()
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.photoSet.notice == .librarySaveFailed(.libraryError(.drawingNotWritten)))
        #expect(writer.additions.isEmpty)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [.saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1"))])
        #expect(writer.additions.count == 1)
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
