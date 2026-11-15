//
//  StorageFullTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// A pick that a full device cannot copy.
private struct OutOfSpacePick: PhotoLibraryPick {

    func loadFiles() async throws -> LibraryPickFiles {
        throw CocoaError(.fileWriteOutOfSpace)
    }
}

/// A renderer that writes the copies the test lets through, and fails the others for want of room.
private actor FullDeviceRenderer: MarkupRenderer {
    private let failingCopyNumbers: Set<Int>
    private var copyCount = 0

    init(failingCopyNumbers: Set<Int>) {
        self.failingCopyNumbers = failingCopyNumbers
    }

    func image(of drawing: MarkupDrawing, pixelSize: CGSize) throws -> CGImage {
        throw MarkupFailure.notEnoughStorage
    }

    func writeCopy(
        of photoURL: URL,
        with drawing: MarkupDrawing,
        output: CameraFlowOutput,
        into directory: URL
    ) async throws -> URL {
        copyCount += 1
        guard !failingCopyNumbers.contains(copyCount) else {
            throw MarkupFailure.notEnoughStorage
        }
        let copyURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        try FlowTestSupport.makeJPEG().write(to: copyURL, options: .withoutOverwriting)
        return copyURL
    }
}

/// A device without room, as the set says it: a pick, the copy with a drawing and the copy for the photo library
/// that cannot be written name the storage, not a fault of the photo.
@MainActor
@Suite("A full device as the set says it", .temporaryDirectory, .timeLimit(.minutes(1)))
struct StorageFullTests {

    @Test("A pick a full device cannot load says the storage is full")
    func pick() async throws {
        let harness = FlowHarness()
        let flow = harness.makeFlow()
        await flow.camera.start()
        try await harness.importLibraryPhoto(into: flow)
        await flow.importPicks([OutOfSpacePick()])
        #expect(flow.photoSet.notice == .notEnoughStorage)
        #expect(FlowText(.system).message(for: PhotoSetNotice.notEnoughStorage) == "Not enough storage")
        #expect(flow.photoSet.count == 1)
        flow.photoSet.discard()
    }

    @Test("A copy with a drawing a full device cannot write keeps the set open and says the storage is full")
    func markedUpCopy() async throws {
        let files = CaptureTestSupport.makeFileStore()
        let renderer = FullDeviceRenderer(failingCopyNumbers: [1])
        let photoSet = PhotoSetModel(limit: .unlimited, fileStore: files, renderer: renderer) { _ in
            Issue.record("Nothing is handed over")
        }
        try await importPhoto(into: photoSet)
        let photo = try #require(photoSet.photos.first)
        photoSet.setDrawing(try FlowTestSupport.makeDrawing(), ofPhoto: photo.id)
        await photoSet.handOver()
        #expect(photoSet.notice == .notEnoughStorage)
        #expect(photoSet.hasEnded == false)
        photoSet.discard()
    }

    @Test("The copy for the photo library a full device cannot write leaves the photo unsaved for want of room")
    func libraryCopy() async throws {
        let harness = FlowHarness()
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let renderer = FullDeviceRenderer(failingCopyNumbers: [2, 4])
        var handedOver: [[CameraFlowPhoto]] = []
        let photoSet = PhotoSetModel(
            limit: .unlimited,
            fileStore: harness.files,
            output: Self.changingOutput,
            librarySaving: saving,
            renderer: renderer
        ) { handedOver.append($0) }
        let camera = makeCaptureModel(
            service: harness.service,
            output: Self.changingOutput,
            librarySaving: saving,
            files: harness.files,
            admission: photoSet,
            onCapture: photoSet.add
        )
        await camera.start()
        await camera.capture()
        let photo = try #require(photoSet.photos.first)
        photoSet.setDrawing(try FlowTestSupport.makeDrawing(), ofPhoto: photo.id)
        await photoSet.handOver()
        #expect(photoSet.notice == .librarySaveFailed(.libraryError(.notEnoughSpace)))
        await photoSet.handOver()
        let photos = try #require(handedOver.first)
        #expect(photos.map(\.photoLibrarySave) == [.failed(.libraryError(.notEnoughSpace))])
        #expect(writer.additions.isEmpty)
        try FlowTestSupport.discardFiles(of: photos)
    }

    /// An output that changes the camera's photo, so the library gets a copy of its own at full size.
    private static var changingOutput: CameraFlowOutput {
        var output = CameraFlowOutput()
        output.format = .jpeg(quality: 0.8)
        return output
    }

    private func importPhoto(into photoSet: PhotoSetModel) async throws {
        let data = try FlowTestSupport.makeJPEG()
        await photoSet.importPicks([FakeLibraryPick(data: data)])
    }
}
