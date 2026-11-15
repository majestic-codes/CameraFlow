//
//  PhotoSetImportTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("Photo set: import from the photo library", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoSetImportTests {
    let files = CaptureTestSupport.makeFileStore()

    private func makeSet(limit: CameraFlowPhotoLimit = .unlimited) -> PhotoSetModel {
        PhotoSetModel(limit: limit, fileStore: files, renderer: RecordingMarkupRenderer()) { _ in
            Issue.record("Nothing is handed over")
        }
    }

    @Test("Picks join the set in their order, after what it holds, as the library's files byte for byte")
    func importsInOrder() async throws {
        let photoSet = makeSet()
        let capture = try FlowTestSupport.makeCapture(in: files)
        photoSet.add(capture)
        let heic = try DevicePhotoFixture.make()
        let jpeg = try FlowTestSupport.makeJPEG()
        let picks = [FakeLibraryPick(data: heic), FakeLibraryPick(data: jpeg, fileExtension: "jpeg")]
        await photoSet.importPicks(picks)
        #expect(photoSet.photos.map(\.source) == [.camera, .photoLibrary, .photoLibrary])
        #expect(photoSet.photos.map(\.contentType) == [.jpeg, .heic, .jpeg])
        #expect(photoSet.photos.first?.id == capture.id)
        let stored = try photoSet.photos.dropFirst().map { try Data(contentsOf: $0.fileURL) }
        #expect(stored == [heic, jpeg])
        #expect(photoSet.photos.allSatisfy { $0.fileURL.deletingLastPathComponent() == files.directory })
        #expect(photoSet.isImporting == false)
        #expect(photoSet.notice == nil)
        photoSet.discard()
    }

    @Test("A set is not handed over while a pick is still loading, and is handed over whole once it is in")
    func handOverWaitsForPicks() async throws {
        var handedOver: [[CameraFlowPhoto]] = []
        let photoSet = PhotoSetModel(limit: .unlimited, fileStore: files, renderer: RecordingMarkupRenderer()) {
            handedOver.append($0)
        }
        photoSet.add(try FlowTestSupport.makeCapture(in: files))
        let gate = CallGate()
        let pick = FakeLibraryPick(data: try FlowTestSupport.makeJPEG(), gate: gate)
        let importing = Task { await photoSet.importPicks([pick]) }
        await gate.arrival()
        #expect(photoSet.isImporting)
        await photoSet.handOver()
        #expect(handedOver.isEmpty)
        #expect(photoSet.hasEnded == false)
        #expect(photoSet.count == 1)
        await gate.open()
        await importing.value
        await photoSet.handOver()
        try #require(handedOver.map(\.count) == [2])
        try FlowTestSupport.discardFiles(of: handedOver[0])
    }

    @Test("A set of library photos alone holds no camera photo")
    func libraryOnly() async throws {
        let photoSet = makeSet()
        let data = try FlowTestSupport.makeJPEG()
        await photoSet.importPicks([FakeLibraryPick(data: data)])
        #expect(photoSet.count == 1)
        #expect(photoSet.hasCameraPhotos == false)
        photoSet.discard()
    }

    @Test("While files load the set is importing, and the picks hold their places against the limit")
    func loadingHoldsPlaces() async throws {
        let photoSet = makeSet(limit: .maximum(3))
        let gate = CallGate()
        let data = try FlowTestSupport.makeJPEG()
        let picks = [FakeLibraryPick(data: data, gate: gate), FakeLibraryPick(data: data, gate: gate)]
        let importing = Task { await photoSet.importPicks(picks) }
        await gate.arrival()
        #expect(photoSet.isImporting)
        #expect(photoSet.pendingImportCount == 2)
        #expect(photoSet.isEmpty)
        #expect(photoSet.remainingCapacity == 1)
        try photoSet.add(FlowTestSupport.makeCapture(in: files))
        #expect(photoSet.isFull)
        #expect(photoSet.captureRefusal(photosInFlight: 0) == .captureLimitReached(3))
        await gate.open()
        await importing.value
        #expect(photoSet.isImporting == false)
        #expect(photoSet.photos.map(\.source) == [.camera, .photoLibrary, .photoLibrary])
        #expect(photoSet.notice == nil)
        photoSet.discard()
    }

    @Test("A pick that cannot be loaded is skipped and reported, and the others join the set")
    func failedPick() async throws {
        let photoSet = makeSet()
        let data = try FlowTestSupport.makeJPEG()
        let picks = [
            FakeLibraryPick(data: data),
            FakeLibraryPick(data: nil),
            FakeLibraryPick(data: Data("not a photo".utf8)),
            FakeLibraryPick(data: data)
        ]
        await photoSet.importPicks(picks)
        #expect(photoSet.count == 2)
        #expect(photoSet.notice == .importFailed(count: 2))
        #expect(photoSet.isImporting == false)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: files.directory.path)
        #expect(leftovers.count == 2)
        photoSet.discard()
    }

    @Test("Picks beyond the limit are left out and reported")
    func picksBeyondLimit() async throws {
        let photoSet = makeSet(limit: .maximum(2))
        try photoSet.add(FlowTestSupport.makeCapture(in: files))
        let data = try FlowTestSupport.makeJPEG()
        await photoSet.importPicks([FakeLibraryPick(data: data), FakeLibraryPick(data: data)])
        #expect(photoSet.count == 2)
        #expect(photoSet.isFull)
        #expect(photoSet.notice == .limitReached(2))
        await photoSet.importPicks([FakeLibraryPick(data: data)])
        #expect(photoSet.count == 2)
        #expect(photoSet.notice == .limitReached(2))
        photoSet.discard()
    }

    enum Change: CaseIterable {
        case anotherImport
        case capture
        case removal
    }

    @Test("The notice goes when the set changes again", arguments: Change.allCases)
    func noticeCleared(by change: Change) async throws {
        let photoSet = makeSet()
        let first = try FlowTestSupport.makeCapture(in: files)
        photoSet.add(first)
        await photoSet.importPicks([FakeLibraryPick(data: nil)])
        #expect(photoSet.notice == .importFailed(count: 1))
        switch change {
        case .anotherImport:
            let data = try FlowTestSupport.makeJPEG()
            await photoSet.importPicks([FakeLibraryPick(data: data)])
        case .capture:
            try photoSet.add(FlowTestSupport.makeCapture(in: files))
        case .removal:
            photoSet.remove(FlowPhoto(capture: first))
        }
        #expect(photoSet.notice == nil)
        photoSet.discard()
    }

    @Test("A file that arrives after the set was discarded is deleted, and the rest is not loaded")
    func discardedWhileLoading() async throws {
        let photoSet = makeSet()
        let gate = CallGate()
        let data = try FlowTestSupport.makeJPEG()
        let picks = [FakeLibraryPick(data: data, gate: gate), FakeLibraryPick(data: data, gate: gate)]
        let importing = Task { await photoSet.importPicks(picks) }
        await gate.arrival()
        photoSet.discard()
        await gate.open()
        await importing.value
        let loadedCount = await gate.arrivalCount
        #expect(loadedCount == 1)
        #expect(photoSet.isEmpty)
        #expect(photoSet.isImporting == false)
        #expect(photoSet.notice == nil)
        #expect(FlowTestSupport.fileExists(files.directory) == false)
    }

    @Test("A file that cannot be read and arrives after the set was discarded leaves no directory behind")
    func unreadableFileAfterDiscard() async {
        let photoSet = makeSet()
        let gate = CallGate()
        let pick = FakeLibraryPick(data: Data("not a photo".utf8), gate: gate)
        let importing = Task { await photoSet.importPicks([pick]) }
        await gate.arrival()
        photoSet.discard()
        await gate.open()
        await importing.value
        #expect(photoSet.isEmpty)
        #expect(FlowTestSupport.fileExists(files.directory) == false)
    }

    @Test("A set that has ended imports nothing")
    func endedSet() async {
        let photoSet = makeSet()
        photoSet.discard()
        let gate = CallGate()
        await photoSet.importPicks([FakeLibraryPick(data: nil, gate: gate)])
        let loadedCount = await gate.arrivalCount
        #expect(loadedCount == 0)
        #expect(photoSet.isEmpty)
        #expect(FlowTestSupport.fileExists(files.directory) == false)
    }
}
