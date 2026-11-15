//
//  CheckMarkSaveFailureTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import os
import Testing
@_spi(Testing) @testable import CameraFlow

/// A library that fails the adds with the numbers the test names, counted from one, and takes the others.
private final class NumberedFailureWriter: PhotoLibraryWriter {
    private let failingNumbers: Set<Int>
    private let failure: CameraFlowPhotoLibraryError
    private let addCount = OSAllocatedUnfairLock(initialState: 0)

    init(failingNumbers: Set<Int>, failure: CameraFlowPhotoLibraryError) {
        self.failingNumbers = failingNumbers
        self.failure = failure
    }

    /// How many adds were asked for.
    var adds: Int {
        addCount.withLock(\.self)
    }

    func authorizationStatus(for access: PhotoLibraryAccess) -> PhotoLibraryAuthorization {
        .authorized
    }

    func requestAuthorization(for access: PhotoLibraryAccess) async -> PhotoLibraryAuthorization {
        .authorized
    }

    func add(
        _ entry: PhotoLibraryEntry,
        toAlbumNamed albumName: String?
    ) async throws(CameraFlowPhotoLibraryError) -> CameraFlowPhotoLibraryAsset {
        let number = addCount.withLock { count in
            count += 1
            return count
        }
        guard !failingNumbers.contains(number) else {
            throw failure
        }
        return CameraFlowPhotoLibraryAsset(localIdentifier: "asset-\(number)")
    }
}

/// The drawing of a photo the library took at a check mark that left the set open, then and at the next check mark,
/// and whether its asset misses the drawing the photo is handed over with.
struct DrawingBetweenCheckMarks: Sendable, CustomTestStringConvertible {
    let name: String
    /// The text of the drawing at the first check mark, nil for none.
    let first: String?
    /// The text of the drawing at the next check mark, nil for none.
    let next: String?
    let isMissingDrawing: Bool

    static let all = [
        Self(name: "no drawing", first: nil, next: nil, isMissingDrawing: false),
        Self(name: "a drawing added after the save", first: nil, next: "added", isMissingDrawing: true),
        Self(name: "the same drawing kept again", first: "kept", next: "kept", isMissingDrawing: false),
        Self(name: "a drawing changed after the save", first: "before", next: "after", isMissingDrawing: true),
        Self(name: "a drawing taken off after the save", first: "removed", next: nil, isMissingDrawing: false)
    ]

    var testDescription: String {
        name
    }
}

/// A save to the photo library that fails at the check mark, where the flow would close with it: the set stays open
/// once to say so, and the next check mark hands it over.
@MainActor
@Suite("A save that fails at the check mark", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CheckMarkSaveFailureTests {
    let harness = FlowHarness()

    /// A flow that saves its camera photos when the set is accepted, over the library.
    private func makeFlow(
        writer: any PhotoLibraryWriter,
        completion: CameraFlowCompletion = .userConfirms
    ) -> TestFlowModel {
        var saving = CameraFlowPhotoLibrarySaving()
        saving.isEnabled = CameraFlowSetting(true)
        let librarySaving = PhotoLibrarySavingModel(saving: saving, isOn: true, writer: writer)
        let limit: CameraFlowPhotoLimit = completion == .afterOnePhoto ? .single : .unlimited
        return harness.makeFlow(limit: limit, librarySaving: librarySaving, completion: completion)
    }

    @Test("A full library keeps the set open and says so, and the next check mark hands the set over")
    func fullLibrary() async throws {
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        writer.failSaves(with: .notEnoughSpace)
        let flow = makeFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.accept()
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.photoSet.hasEnded == false)
        #expect(flow.notice == .photoSet(.librarySaveFailed(.libraryError(.notEnoughSpace))))
        #expect(FlowText(.system).notice(for: flow) == "Not enough storage")
        #expect(flow.canShoot)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [.failed(.libraryError(.notEnoughSpace))])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("The next check mark saves only the photos the library did not take, so none is added twice")
    func savesOnlyWhatFailed() async throws {
        let refusal = CameraFlowPhotoLibraryError.changeRefused(errorDomain: "NSCocoaErrorDomain", errorCode: 4)
        let writer = NumberedFailureWriter(failingNumbers: [2], failure: refusal)
        let flow = makeFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        await flow.accept()
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.photoSet.notice == .librarySaveFailed(.libraryError(refusal)))
        #expect(writer.adds == 2)
        await flow.accept()
        #expect(writer.adds == 3)
        let handedOver = try #require(harness.outcome.handedOver.first)
        let saves: [CameraFlowPhotoLibrarySave?] = [
            .saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")),
            .saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-3"))
        ]
        #expect(handedOver.map(\.photoLibrarySave) == saves)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test(
        "A photo the library took at a check mark that left the set open misses a drawing it got or changed after it",
        arguments: DrawingBetweenCheckMarks.all
    )
    func drawingAfterPartialSave(drawings: DrawingBetweenCheckMarks) async throws {
        let writer = NumberedFailureWriter(failingNumbers: [2], failure: .noAssetCreated)
        let flow = makeFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        let saved = try #require(flow.photoSet.photos.first)
        let first = try drawings.first.map { try FlowTestSupport.makeDrawing($0) }
        flow.photoSet.setDrawing(first, ofPhoto: saved.id)
        await flow.accept()
        #expect(harness.outcome.handedOver.isEmpty)
        let next = try drawings.next.map { try FlowTestSupport.makeDrawing($0) }
        flow.photoSet.setDrawing(next, ofPhoto: saved.id)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        let asset = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1", isMissingDrawing: drawings.isMissingDrawing)
        #expect(handedOver.first?.photoLibrarySave == .saved(asset))
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("The exit alert counts a photo the library took at the check mark as kept")
    func exitAfterPartialSave() async throws {
        let writer = NumberedFailureWriter(failingNumbers: [2], failure: .noAssetCreated)
        let flow = makeFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        await flow.accept()
        let unsaved = try #require(flow.photoSet.photos.last)
        flow.photoSet.remove(unsaved)
        flow.requestExit()
        #expect(flow.exitConfirmation == ExitConfirmation(photoCount: 1, hasCameraPhotos: false))
        flow.confirmExit()
        #expect(harness.outcome.exitCount == 1)
    }

    @Test("A set whose screen went away while it was saved is handed over all the same, with the failure")
    func discardedWhileSaving() async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(authorization: .authorized, gate: gate)
        writer.failSaves(with: .noAssetCreated)
        let flow = makeFlow(writer: writer)
        await flow.camera.start()
        await flow.camera.capture()
        let accepting = Task { await flow.accept() }
        await gate.arrival()
        flow.photoSet.discard()
        await gate.open()
        await accepting.value
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [.failed(.libraryError(.noAssetCreated))])
        #expect(FlowTestSupport.fileExists(handedOver[0].original.url))
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A flow that ends after one photo stays open on a failed save, and the check mark hands the photo over")
    func afterOnePhoto() async throws {
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        writer.failSaves(with: .notEnoughSpace)
        let flow = makeFlow(writer: writer, completion: .afterOnePhoto)
        await flow.camera.start()
        await flow.camera.capture()
        await settle { flow.photoSet.notice == .librarySaveFailed(.libraryError(.notEnoughSpace)) }
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.canAccept)
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [.failed(.libraryError(.notEnoughSpace))])
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("Photos saved right after their shot are handed over at the first check mark, even with a failed save")
    func afterEachPhotoHandsOver() async throws {
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        writer.failSaves(with: .noAssetCreated)
        let saving = CaptureTestSupport.makeLibrarySaving(moment: .afterEachPhoto, writer: writer)
        let flow = harness.makeFlow(librarySaving: saving)
        await flow.camera.start()
        await flow.camera.capture()
        await settle { flow.photoSet.shutterSaves.results.count == 1 }
        await flow.accept()
        let handedOver = try #require(harness.outcome.handedOver.first)
        #expect(handedOver.map(\.photoLibrarySave) == [.failed(.libraryError(.noAssetCreated))])
        try FlowTestSupport.discardFiles(of: handedOver)
    }
}
