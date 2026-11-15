//
//  CameraFlowPhotoLibrarySavingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Saving to the photo library", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraFlowPhotoLibrarySavingTests {
    // MARK: - When

    @Test("Nothing reaches the library while the set is open, and the check mark saves every photo in it")
    func savesOnAccept() async throws {
        let writer = FakePhotoLibraryWriter()
        let (harness, flow) = makeSavingFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        flow.showReview()
        #expect(writer.additions.isEmpty)
        #expect(writer.requestedAccess.isEmpty)
        await flow.accept()
        #expect(writer.requestedAccess == [.addOnly])
        #expect(writer.additions.count == 2)
        let handedOver = try #require(harness.outcome.handedOver.first)
        let saves = handedOver.map(\.photoLibrarySave)
        let first = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")
        let second = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-2")
        #expect(saves == [.saved(first), .saved(second)])
        #expect(writer.additions.map(\.entry.photoFileURL) == handedOver.map(\.original.url))
        #expect(writer.additions.allSatisfy { $0.albumName == nil && $0.entry.markedUpFileURL == nil })
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A photo deleted in the review never reaches the library")
    func deletedPhotoIsNotSaved() async throws {
        let writer = FakePhotoLibraryWriter()
        let (harness, flow) = makeSavingFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        let photos = flow.photoSet.photos
        try #require(photos.count == 2)
        flow.photoSet.remove(photos[0])
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.id) == [photos[1].id])
        #expect(writer.additions.count == 1)
        #expect(writer.additions.map(\.entry.photoFileURL) == [photos[1].fileURL])
        #expect(FlowTestSupport.fileExists(photos[0].fileURL) == false)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("Leaving with the cross saves nothing, and the alert says the camera photos are gone")
    func cancelSavesNothing() async {
        let writer = FakePhotoLibraryWriter()
        let (harness, flow) = makeSavingFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 1, hasCameraPhotos: true))
        flow.confirmExit()
        #expect(writer.additions.isEmpty)
        #expect(harness.outcome.exitCount == 1)
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(FlowTestSupport.fileExists(harness.files.directory) == false)
    }

    @Test("Saving off saves nothing at the check mark, and the full picture kept for the library goes with it")
    func savingOff() async throws {
        let writer = FakePhotoLibraryWriter()
        let (harness, flow) = makeSavingFlow(writer: writer, isOn: false)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.accept()
        #expect(writer.additions.isEmpty)
        #expect(writer.requestedAccess.isEmpty)
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [nil])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    // MARK: - Access

    @Test("The library is asked for add-only access once, when saving was on from the start and the set is accepted")
    func asksOnceForAddOnlyAccess() async throws {
        let writer = FakePhotoLibraryWriter()
        let (harness, flow) = makeSavingFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        #expect(writer.requestedAccess.isEmpty)
        await flow.accept()
        #expect(writer.requestedAccess == [.addOnly])
        let handedOver = try #require(harness.outcome.handedOver.first)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("An album needs read-write access and gets the asset in one change")
    func album() async throws {
        let writer = FakePhotoLibraryWriter()
        let (harness, flow) = makeSavingFlow(writer: writer, destination: .album(named: "Field"))
        await flow.camera.start()
        await flow.camera.capture()
        await flow.accept()
        #expect(writer.requestedAccess == [.readWrite])
        #expect(writer.additions.map(\.albumName) == ["Field"])
        let handedOver = try #require(harness.outcome.handedOver.first)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test(
        "Access refused at the check mark fails the save openly, and the set is handed over all the same at the next",
        arguments: [
            (PhotoLibraryAuthorization.denied, CameraFlowPhotoLibrarySaveFailure.accessDenied),
            (.restricted, .accessRestricted)
        ]
    )
    func refusedAccess(
        authorization: PhotoLibraryAuthorization,
        failure: CameraFlowPhotoLibrarySaveFailure
    ) async throws {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: authorization)
        let (harness, flow) = makeSavingFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        #expect(flow.canAccept)
        await flow.accept()
        #expect(writer.requestedAccess == [.addOnly])
        #expect(writer.additions.isEmpty)
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.photoSet.notice == .librarySaveFailed(failure))
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        try #require(handedOver.map(\.photoLibrarySave) == [.failed(failure)])
        #expect(FlowTestSupport.fileExists(handedOver[0].original.url))
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("Limited access is enough for the library and not for an album")
    func limitedAccess() async throws {
        let libraryWriter = FakePhotoLibraryWriter(authorization: .limited)
        let (libraryHarness, libraryFlow) = makeSavingFlow(writer: libraryWriter)
        await libraryFlow.camera.start()
        await libraryFlow.camera.capture()
        await libraryFlow.accept()
        #expect(libraryWriter.additions.count == 1)
        let librarySet = try #require(libraryHarness.outcome.handedOver.first)
        try FlowTestSupport.discardFiles(of: librarySet)

        let albumWriter = FakePhotoLibraryWriter(authorization: .limited)
        let (albumHarness, albumFlow) = makeSavingFlow(writer: albumWriter, destination: .album(named: "Field"))
        await albumFlow.camera.start()
        #expect(albumFlow.camera.notice == .librarySavingRefused(.limitedAccess))
        await albumFlow.camera.capture()
        await albumFlow.accept()
        #expect(albumWriter.additions.isEmpty)
        let handedOver = try #require(albumHarness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [nil])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test(
        "A library that does not take the photo says why once and reports it as a typed value, per photo, saving on",
        arguments: [
            CameraFlowPhotoLibraryError.changeRefused(errorDomain: "PHPhotosErrorDomain", errorCode: 3302),
            .changeRefused(errorDomain: "NSCocoaErrorDomain", errorCode: 4),
            .noAssetCreated,
            .drawingNotWritten
        ]
    )
    func libraryError(error: CameraFlowPhotoLibraryError) async throws {
        let writer = FakePhotoLibraryWriter()
        writer.failSaves(with: error)
        let (harness, flow) = makeSavingFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        await flow.accept()
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.photoSet.notice == .librarySaveFailed(.libraryError(error)))
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == Array(repeating: .failed(.libraryError(error)), count: 2))
        #expect(FlowText(.system).message(for: .libraryError(error)) == "The photo could not be saved to the library")
        #expect(flow.camera.settings.isLibrarySavingOn)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    // MARK: - Timing

    @Test("The set is handed over once every photo has been saved, in the order of the set")
    func savesBeforeHandOver() async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(gate: gate)
        let (harness, flow) = makeSavingFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        let handingOver = Task { await flow.accept() }
        await gate.arrival()
        #expect(flow.isHandingOver)
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.canShoot == false)
        await gate.open()
        await handingOver.value
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [.saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1"))])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("Leaving is refused while the set is being saved")
    func exitWhileSaving() async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(gate: gate)
        let (harness, flow) = makeSavingFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        let handingOver = Task { await flow.accept() }
        await gate.arrival()
        flow.confirmExit()
        #expect(harness.outcome.exitCount == 0)
        await gate.open()
        await handingOver.value
        let handedOver = try #require(harness.outcome.handedOver.first)
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
