//
//  CameraFlowPhotoLibrarySaveMomentTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// Saving each camera photo to the photo library right after its shot: once, never for a pick, kept when the photo
/// or the set goes, with its files alive until the save has read them, and with its failure on the screen and in
/// the hand-over.
@MainActor
@Suite("Saving to the photo library right after each shot", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraFlowPhotoLibrarySaveMomentTests {

    @Test("By default the photos are saved when the set is accepted")
    func acceptedByDefault() {
        #expect(CameraFlowPhotoLibrarySaving().moment == .whenSetAccepted)
    }

    @Test("Every shot is saved at once, and the check mark reports the saves without saving again")
    func savesAfterEachShot() async throws {
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        let (harness, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await settle { flow.photoSet.shutterSaves.results.count == 1 }
        #expect(writer.additions.count == 1)
        await flow.camera.capture()
        await settle { flow.photoSet.shutterSaves.results.count == 2 }
        await flow.accept()
        #expect(writer.additions.count == 2)
        let handedOver = try #require(harness.outcome.handedOver.first)
        let expectedSaves: [CameraFlowPhotoLibrarySave?] = [
            .saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")),
            .saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-2"))
        ]
        #expect(handedOver.map(\.photoLibrarySave) == expectedSaves)
        #expect(writer.additions.map(\.entry.photoFileURL) == handedOver.map(\.original.url))
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("The check mark waits for a save still running and hands the photo over with it")
    func acceptWaitsForSave() async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(authorization: .authorized, gate: gate)
        let (harness, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await gate.arrival()
        let accepting = Task { await flow.accept() }
        await settleQueuedWork()
        #expect(harness.outcome.handedOver.isEmpty)
        await gate.open()
        await accepting.value
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [.saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1"))])
        #expect(writer.additions.count == 1)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A deleted photo keeps its saved copy, and its files go only once the save has read them")
    func deletedPhotoKeepsCopy() async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(authorization: .authorized, gate: gate)
        let (harness, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await gate.arrival()
        let photo = try #require(flow.photoSet.photos.first)
        flow.photoSet.remove(photo)
        #expect(FlowTestSupport.fileExists(photo.fileURL))
        await gate.open()
        await settle { FlowTestSupport.fileExists(photo.fileURL) == false }
        #expect(writer.additions.count == 1)
        #expect(flow.photoSet.isEmpty)
        #expect(harness.outcome.handedOver.isEmpty)
    }

    @Test("Leaving with the cross keeps the saved copies, lets the running saves end and then deletes the files")
    func cancelKeepsCopies() async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(authorization: .authorized, gate: gate)
        let (harness, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await gate.arrival()
        let photo = try #require(flow.photoSet.photos.first)
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 1, hasCameraPhotos: true))
        flow.confirmExit()
        #expect(harness.outcome.exitCount == 1)
        #expect(FlowTestSupport.fileExists(photo.fileURL))
        await gate.open()
        await settle { FlowTestSupport.fileExists(harness.files.directory) == false }
        #expect(writer.additions.count == 1)
        #expect(harness.outcome.handedOver.isEmpty)
    }

    @Test("A save that fails once the set was left says nothing on the screen")
    func failedSaveAfterExit() async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(authorization: .authorized, gate: gate)
        writer.failSaves(with: .changeRefused(errorDomain: "PHPhotosErrorDomain", errorCode: 3302))
        let (harness, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await gate.arrival()
        flow.requestExit()
        flow.confirmExit()
        await gate.open()
        await settle { FlowTestSupport.fileExists(harness.files.directory) == false }
        #expect(flow.photoSet.notice == nil)
    }

    @Test("Once its photos are saved, the exit alert no longer says they will be gone")
    func exitAlertCountsSavedPhotos() async {
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        let (_, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await settle { flow.photoSet.shutterSaves.results.count == 1 }
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 1, hasCameraPhotos: false))
        flow.confirmExit()
    }

    @Test("A pick from the library is never saved to it again")
    func picksAreNotSaved() async throws {
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        let (harness, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto)
        await flow.camera.start()
        try await harness.importLibraryPhoto(into: flow)
        await settleQueuedWork()
        #expect(writer.additions.isEmpty)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [nil])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A drawing added after the save goes to the app, the library keeps the photo as it was taken, and says so")
    func drawingAfterSave() async throws {
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        let (harness, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await settle { flow.photoSet.shutterSaves.results.count == 1 }
        let photo = try #require(flow.photoSet.photos.first)
        flow.photoSet.setDrawing(try FlowTestSupport.makeDrawing(), ofPhoto: photo.id)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(writer.additions.count == 1)
        #expect(writer.additions.first?.entry.markedUpFileURL == nil)
        #expect(handedOver.first?.markedUp?.url != nil)
        let asset = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1", isMissingDrawing: true)
        #expect(handedOver.first?.photoLibrarySave == .saved(asset))
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A failed save keeps the photo, says so on the screen and reaches the app")
    func failedSave() async throws {
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        writer.failSaves(with: .changeRefused(errorDomain: "PHPhotosErrorDomain", errorCode: 3302))
        let (harness, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await settle { flow.photoSet.shutterSaves.results.count == 1 }
        let refusal = CameraFlowPhotoLibraryError.changeRefused(errorDomain: "PHPhotosErrorDomain", errorCode: 3302)
        let failure = CameraFlowPhotoLibrarySaveFailure.libraryError(refusal)
        #expect(flow.photoSet.notice == .librarySaveFailed(failure))
        #expect(flow.photoSet.count == 1)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        try #require(handedOver.map(\.photoLibrarySave) == [.failed(failure)])
        #expect(FlowTestSupport.fileExists(handedOver[0].original.url))
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test(
        "Access refused at the first save fails it, says why and switches off a saving the user owns",
        arguments: [
            (
                PhotoLibraryAuthorization.denied,
                CameraFlowPhotoLibrarySaving.Destination.library,
                CameraFlowPhotoLibrarySaveFailure.accessDenied
            ),
            (.restricted, .library, .accessRestricted),
            (.limited, .album(named: "Field"), .limitedAccess)
        ]
    )
    func refusedAccess(
        authorization: PhotoLibraryAuthorization,
        destination: CameraFlowPhotoLibrarySaving.Destination,
        failure: CameraFlowPhotoLibrarySaveFailure
    ) async throws {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: authorization)
        let (harness, flow) = makeSavingFlow(writer: writer, destination: destination, moment: .afterEachPhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await settle { flow.photoSet.shutterSaves.results.count == 1 }
        #expect(writer.additions.isEmpty)
        #expect(flow.photoSet.notice == .librarySaveFailed(failure))
        #expect(flow.camera.settings.isLibrarySavingOn == false)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [.failed(failure)])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("Limited access is enough for the library itself")
    func limitedAccessForLibrary() async throws {
        let writer = FakePhotoLibraryWriter(authorization: .limited)
        let (harness, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await settle { flow.photoSet.shutterSaves.results.count == 1 }
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [.saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1"))])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A shot taken while saving is off is not saved, and the ones after switching it on are")
    func switchDecidesPerShot() async throws {
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        let (harness, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto, isOn: false)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.settings.select(isLibrarySavingEnabled: true)
        await flow.camera.capture()
        await settle { flow.photoSet.shutterSaves.results.count == 1 }
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        let asset = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")
        #expect(handedOver.map(\.photoLibrarySave) == [nil, .saved(asset)])
        #expect(writer.additions.count == 1)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("Switching saving off keeps what was saved and saves nothing more")
    func switchOffKeepsSaved() async throws {
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        let (harness, flow) = makeSavingFlow(writer: writer, moment: .afterEachPhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await settle { flow.photoSet.shutterSaves.results.count == 1 }
        await flow.camera.settings.select(isLibrarySavingEnabled: false)
        await flow.camera.capture()
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        let asset = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")
        #expect(handedOver.map(\.photoLibrarySave) == [.saved(asset), nil])
        #expect(writer.additions.count == 1)
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
