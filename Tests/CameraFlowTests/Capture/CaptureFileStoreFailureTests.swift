//
//  CaptureFileStoreFailureTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// The store on a file system that refuses: every refusal reaches the caller as `cannotStore`, and a cleanup
/// that cannot be done leaves the directory for a later run.
@MainActor
@Suite("Capture file store: a file system that refuses", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CaptureFileStoreFailureTests {
    private let fileManager = FileManager.default

    private func makeStore(run: String = "now") -> CaptureFileStore {
        CaptureFileStore(parent: TestDirectory.current, run: run)
    }

    private var root: URL {
        TestDirectory.current.appendingPathComponent("CameraFlow", isDirectory: true)
    }

    private func ledger(run: String) -> URL {
        root.appendingPathComponent(".runs", isDirectory: true).appendingPathComponent(run, isDirectory: true)
    }

    private func setPermissions(_ permissions: Int, of url: URL) throws {
        try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
    }

    private func expectCannotStore(
        _ prefix: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ body: () throws -> Void
    ) {
        #expect(sourceLocation: sourceLocation) {
            try body()
        } throws: { error in
            guard case let .cannotStore(reason) = error as? CameraServiceError else { return false }
            return reason.hasPrefix(prefix)
        }
    }

    // MARK: - Writing and moving

    @Test("A photo of a type without a file name extension is refused before anything is made")
    func typeWithoutExtension() {
        let store = makeStore()
        expectCannotStore("The type public.data has no file name extension") {
            _ = try store.writePhoto(Data([1]), identifier: UUID(), type: .data)
        }
        #expect(fileManager.fileExists(atPath: store.directory.path) == false)
    }

    @Test("A store whose parent is a file cannot make its directory")
    func parentIsFile() throws {
        let file = TestDirectory.current.appendingPathComponent("occupied")
        try Data([0]).write(to: file)
        let store = CaptureFileStore(parent: file, run: "now")
        expectCannotStore("Cannot create the capture directory") {
            _ = try store.writePhoto(Data([1]), identifier: UUID(), type: .jpeg)
        }
    }

    @Test("A photo is never written over the file of another capture with its name, and leaves nothing of itself")
    func neverOverwrites() throws {
        let store = makeStore()
        let identifier = UUID()
        let url = try store.writePhoto(Data([1, 2, 3]), identifier: identifier, type: .jpeg)
        expectCannotStore("Cannot write the photo file") {
            _ = try store.writePhoto(Data([9]), identifier: identifier, type: .jpeg)
        }
        #expect(try Data(contentsOf: url) == Data([1, 2, 3]))
        #expect(try fileManager.contentsOfDirectory(atPath: store.directory.path) == [url.lastPathComponent])
    }

    @Test("A photo the file system refuses leaves no part of itself in the directory")
    func refusedWrite() throws {
        let store = makeStore()
        let kept = try store.writePhoto(Data([1]), identifier: UUID(), type: .jpeg)
        try setPermissions(0o555, of: store.directory)
        expectCannotStore("Cannot write the photo file") {
            _ = try store.writePhoto(Data(count: 4_096), identifier: UUID(), type: .jpeg)
        }
        try setPermissions(0o755, of: store.directory)
        #expect(try fileManager.contentsOfDirectory(atPath: store.directory.path) == [kept.lastPathComponent])
    }

    @Test("A file with a mark sits beside the photo of its capture")
    func markedFile() throws {
        let store = makeStore()
        let identifier = UUID()
        let photo = try store.writePhoto(Data([1]), identifier: identifier, type: .heic)
        let marked = try store.writePhoto(Data([2]), identifier: identifier, type: .heic, mark: "camera")
        #expect(photo.lastPathComponent == "\(identifier.uuidString).heic")
        #expect(marked.lastPathComponent == "\(identifier.uuidString)-camera.heic")
    }

    @Test("A movie, a library photo and a copy that are not where they should be are reported")
    func missingSources() {
        let store = makeStore()
        let missing = TestDirectory.current.appendingPathComponent("missing.mov")
        expectCannotStore("Cannot move the Live Photo movie") {
            _ = try store.moveMovie(from: missing, identifier: UUID())
        }
        expectCannotStore("Cannot move the library photo") {
            _ = try store.moveLibraryPhoto(from: missing, identifier: UUID())
        }
        expectCannotStore("Cannot name the copy") {
            _ = try store.moveCopy(from: missing, identifier: UUID(), mark: "dual")
        }
    }

    // MARK: - Cleaning up

    @Test("Discarding a file that is already gone changes nothing else")
    func discardMissing() throws {
        let store = makeStore()
        let kept = try store.writePhoto(Data([1]), identifier: UUID(), type: .jpeg)
        CaptureFileStore.discard(store.directory.appendingPathComponent("gone.jpg"))
        #expect(try fileManager.contentsOfDirectory(atPath: store.directory.path) == [kept.lastPathComponent])
    }

    @Test("A directory that cannot be read stays entered in the ledger, so a later run removes it")
    func unreadableDirectory() throws {
        let store = makeStore(run: "earlier")
        let photo = try store.writePhoto(Data([1]), identifier: UUID(), type: .jpeg)
        try fileManager.removeItem(at: photo)
        try setPermissions(0o000, of: store.directory)
        store.removeDirectoryIfEmpty()
        try setPermissions(0o755, of: store.directory)
        #expect(fileManager.fileExists(atPath: store.directory.path))
        #expect(makeStore(run: "later").removeStaleDirectories() == 1)
        #expect(fileManager.fileExists(atPath: store.directory.path) == false)
    }

    @Test("A ledger entry that cannot be removed leaves the released directory to a later run")
    func lockedLedger() throws {
        let store = makeStore(run: "earlier")
        let photo = try store.writePhoto(Data([1]), identifier: UUID(), type: .jpeg)
        try setPermissions(0o555, of: ledger(run: "earlier"))
        store.releaseToReceiver()
        try setPermissions(0o755, of: ledger(run: "earlier"))
        #expect(fileManager.fileExists(atPath: photo.path))
        #expect(makeStore(run: "later").removeStaleDirectories() == 1)
        #expect(fileManager.fileExists(atPath: photo.path) == false)
    }

    @Test("A ledger that cannot be read removes nothing and stops no flow")
    func damagedLedger() throws {
        let store = makeStore(run: "earlier")
        let photo = try store.writePhoto(Data([1]), identifier: UUID(), type: .jpeg)
        let entries = ledger(run: "earlier")
        try fileManager.removeItem(at: entries)
        try Data([0]).write(to: entries)
        #expect(makeStore(run: "later").removeStaleDirectories() == 0)
        #expect(fileManager.fileExists(atPath: photo.path))
    }

    // MARK: - Delivery

    @Test("A capture that finishes after the screen closed is deleted, and its empty directory with it")
    func deliveryAfterClose() throws {
        let store = makeStore()
        var received: [CameraCapture] = []
        let delivery = CaptureDelivery(files: store) { received.append($0) }
        let first = try FlowTestSupport.makeCapture(in: store)
        delivery.handOver(first)
        #expect(received.map(\.id) == [first.id])
        try CaptureTestSupport.discardFiles(of: first)
        let late = try FlowTestSupport.makeCapture(in: store, withMovie: true)
        delivery.close()
        #expect(delivery.isClosed)
        delivery.handOver(late)
        #expect(received.map(\.id) == [first.id])
        #expect(late.fileURLs.contains { fileManager.fileExists(atPath: $0.path) } == false)
        #expect(fileManager.fileExists(atPath: store.directory.path) == false)
    }
}
