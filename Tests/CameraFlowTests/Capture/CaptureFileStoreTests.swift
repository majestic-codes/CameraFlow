//
//  CaptureFileStoreTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

@MainActor
@Suite("Capture file store: the directories earlier runs left behind", .temporaryDirectory, .timeLimit(.minutes(1)))
final class CaptureFileStoreTests {
    /// A parent of its own, so that no other test and no other process shares the package's folder under it.
    private let parent = FileManager.default.temporaryDirectory
        .appendingPathComponent("CameraFlowTests-stale-\(UUID().uuidString)", isDirectory: true)

    deinit {
        // Best-effort cleanup in a deinit, which cannot throw: the sanctioned `try?`.
        try? FileManager.default.removeItem(at: parent)
    }

    private func makeStore(run: String) -> CaptureFileStore {
        CaptureFileStore(parent: parent, run: run)
    }

    @discardableResult
    private func writePhoto(into store: CaptureFileStore) throws -> URL {
        try store.writePhoto(Data([1, 2, 3]), identifier: UUID(), type: .jpeg)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - What goes

    @Test("A directory an earlier run left behind is removed with its files when a new flow starts")
    func removesStaleDirectory() throws {
        let crashed = makeStore(run: "earlier")
        let photoURL = try writePhoto(into: crashed)
        let removedCount = makeStore(run: "now").removeStaleDirectories()
        #expect(removedCount == 1)
        #expect(exists(photoURL) == false)
        #expect(exists(crashed.directory) == false)
    }

    @Test("Every directory of every earlier run goes, and a second cleanup finds nothing")
    func removesEveryStaleDirectory() throws {
        let stores = [makeStore(run: "first"), makeStore(run: "first"), makeStore(run: "second")]
        for store in stores {
            try writePhoto(into: store)
        }
        let current = makeStore(run: "now")
        #expect(current.removeStaleDirectories() == 3)
        #expect(stores.contains { exists($0.directory) } == false)
        #expect(current.removeStaleDirectories() == 0)
    }

    @Test("A Live Photo movie the camera wrote and nobody moved goes with a later run")
    func removesStaleMovie() throws {
        let movieURL = try CaptureFileStore.temporaryMovieURL(parent: parent)
        try Data([0]).write(to: movieURL)
        #expect(movieURL.path.hasPrefix(parent.appendingPathComponent("CameraFlow").path))
        #expect(makeStore(run: "a later run").removeStaleDirectories() == 1)
        #expect(exists(movieURL) == false)
    }

    @Test("The rendered content of an edit for the photo library is written where a later run cleans up")
    func removesStaleEdit() throws {
        let directory = try CaptureFileStore.temporaryEditDirectory(parent: parent)
        #expect(directory.path.hasPrefix(parent.appendingPathComponent("CameraFlow").path))
        let photo = try OrientedPhotoFixture.makeFile(orientation: 1, type: .jpeg, in: TestDirectory.current)
        let edit = try PhotoLibraryEditFile.write(photo, into: directory)
        #expect(edit.deletingLastPathComponent() == directory)
        #expect(try CaptureFileStore.temporaryEditDirectory(parent: parent) == directory)
        #expect(CaptureFileStore(parent: parent).removeStaleDirectories() == 0)
        #expect(exists(edit))
        #expect(makeStore(run: "a later run").removeStaleDirectories() == 1)
        #expect(exists(edit) == false)
    }

    @Test("The copy of a pick that a kill left behind goes with a later run")
    func removesStalePick() throws {
        let pickURL = try CaptureFileStore.temporaryPickURL(pathExtension: "heic", parent: parent)
        try Data([0]).write(to: pickURL)
        #expect(pickURL.path.hasPrefix(parent.appendingPathComponent("CameraFlow").path))
        #expect(pickURL.pathExtension == "heic")
        #expect(CaptureFileStore(parent: parent).removeStaleDirectories() == 0)
        #expect(exists(pickURL))
        #expect(makeStore(run: "a later run").removeStaleDirectories() == 1)
        #expect(exists(pickURL) == false)
    }

    @Test("A directory handed over to the app goes once the app has emptied it, whichever run handed it over")
    func removesEmptiedReleasedDirectory() throws {
        let earlier = makeStore(run: "earlier")
        let current = makeStore(run: "now")
        var directories: [URL] = []
        for store in [earlier, current] {
            let photoURL = try writePhoto(into: store)
            store.releaseToReceiver()
            try FileManager.default.removeItem(at: photoURL)
            directories.append(store.directory)
        }
        #expect(makeStore(run: "now").removeStaleDirectories() == 2)
        #expect(directories.contains(where: exists) == false)
        #expect(exists(parent.appendingPathComponent("CameraFlow/.runs", isDirectory: true)))
    }

    @Test("An empty directory of a flow that may still be open stays")
    func keepsEmptyDirectoryOfThisRun() throws {
        let open = makeStore(run: "now")
        let photoURL = try writePhoto(into: open)
        try FileManager.default.removeItem(at: photoURL)
        #expect(makeStore(run: "now").removeStaleDirectories() == 0)
        #expect(exists(open.directory))
    }

    @Test("What cannot be read in the ledger is passed over, and every other run is still cleaned up")
    func strayLedgerEntries() throws {
        let first = makeStore(run: "a")
        let last = makeStore(run: "z")
        try writePhoto(into: first)
        try writePhoto(into: last)
        let ledger = parent.appendingPathComponent("CameraFlow/.runs", isDirectory: true)
        try Data([0]).write(to: ledger.appendingPathComponent("m, a file where a run's folder is expected"))
        let current = makeStore(run: "now")
        #expect(current.removeStaleDirectories() == 2)
        #expect(exists(first.directory) == false)
        #expect(exists(last.directory) == false)
        #expect(current.removeStaleDirectories() == 0)
    }

    // MARK: - What stays

    @Test("A directory of this run stays: its flow may still be open")
    func keepsDirectoryOfThisRun() throws {
        let open = makeStore(run: "now")
        let photoURL = try writePhoto(into: open)
        #expect(makeStore(run: "now").removeStaleDirectories() == 0)
        #expect(exists(photoURL))
    }

    @Test("A Live Photo movie of this run stays")
    func keepsMovieOfThisRun() throws {
        let movieURL = try CaptureFileStore.temporaryMovieURL(parent: parent)
        try Data([0]).write(to: movieURL)
        #expect(CaptureFileStore(parent: parent).removeStaleDirectories() == 0)
        #expect(exists(movieURL))
    }

    @Test("Files the app has taken over stay, whichever run handed them over")
    func keepsReleasedDirectory() throws {
        let handedOver = makeStore(run: "earlier")
        let photoURL = try writePhoto(into: handedOver)
        handedOver.releaseToReceiver()
        #expect(makeStore(run: "now").removeStaleDirectories() == 0)
        #expect(exists(photoURL))
    }

    @Test("A file that arrives late in a directory the app took over does not make the directory stale again")
    func lateFileKeepsRelease() throws {
        let handedOver = makeStore(run: "earlier")
        let photoURL = try writePhoto(into: handedOver)
        handedOver.releaseToReceiver()
        let lateURL = try writePhoto(into: handedOver)
        CaptureFileStore.discard(lateURL)
        handedOver.removeDirectoryIfEmpty()
        #expect(makeStore(run: "now").removeStaleDirectories() == 0)
        #expect(exists(photoURL))
    }

    @Test("A directory the package did not make is never touched")
    func keepsForeignDirectory() throws {
        let root = parent.appendingPathComponent("CameraFlow", isDirectory: true)
        let foreign = root.appendingPathComponent("the app's own", isDirectory: true)
        try FileManager.default.createDirectory(at: foreign, withIntermediateDirectories: true)
        let fileURL = foreign.appendingPathComponent("photo.jpg")
        try Data([1]).write(to: fileURL)
        try writePhoto(into: makeStore(run: "earlier"))
        #expect(makeStore(run: "now").removeStaleDirectories() == 1)
        #expect(exists(fileURL))
    }

    @Test("A flow that starts with nothing left behind removes nothing")
    func nothingLeftBehind() {
        #expect(makeStore(run: "now").removeStaleDirectories() == 0)
        #expect(exists(parent) == false)
    }

    @Test("A directory removed once it is empty leaves nothing for a later run to remove")
    func emptiedDirectory() throws {
        let store = makeStore(run: "earlier")
        let photoURL = try writePhoto(into: store)
        CaptureFileStore.discard(photoURL)
        store.removeDirectoryIfEmpty()
        #expect(exists(store.directory) == false)
        #expect(makeStore(run: "now").removeStaleDirectories() == 0)
    }

    // MARK: - Through the flow

    @Test("The files of a set that was handed over survive a later run, and those of a set that was not do not")
    func handOverReleasesDirectory() async throws {
        let acceptedFiles = makeStore(run: "earlier")
        let abandonedFiles = makeStore(run: "earlier")
        var handedOver: [CameraFlowPhoto] = []
        let accepted = PhotoSetModel(limit: .unlimited, fileStore: acceptedFiles, renderer: RecordingMarkupRenderer()) {
            handedOver = $0
        }
        let abandoned = PhotoSetModel(
            limit: .unlimited,
            fileStore: abandonedFiles,
            renderer: RecordingMarkupRenderer()
        ) { _ in }
        let data = try FlowTestSupport.makeJPEG()
        await accepted.importPicks([FakeLibraryPick(data: data)])
        await abandoned.importPicks([FakeLibraryPick(data: data)])
        let abandonedURL = try #require(abandoned.photos.first?.fileURL)
        await accepted.handOver()
        let photo = try #require(handedOver.first)
        #expect(makeStore(run: "now").removeStaleDirectories() == 1)
        #expect(exists(photo.original.url))
        #expect(exists(abandonedURL) == false)
    }
}
