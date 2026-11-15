//
//  CaptureFileStore.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import os
import UniformTypeIdentifiers

/// The temporary directory of one flow, where the files of its captures and of its library photos are kept until
/// they are handed over.
///
/// Every directory the package makes sits in its own `CameraFlow` folder of the temporary directory, and is entered
/// in the ledger beside it (`CaptureDirectoryLedger`) under the run of the program that made it. The entry is taken
/// out when the set is handed over. A directory still entered under an earlier run was left behind by a crash or a
/// kill, and the next flow removes it, as it removes a handed-over directory the app has emptied.
///
/// A file is written whole or not at all: a write that fails, for a full disk among other causes, leaves no part of
/// it behind. A write that fails for want of room says so (`CameraServiceError.notEnoughStorage`).
struct CaptureFileStore: Sendable {
    let directory: URL
    private let ledger: CaptureDirectoryLedger

    private static let logger = Logger.camera("CaptureFileStore")
    private static let rootName = "CameraFlow"
    /// This run of the program: every store and every shared directory made until it ends share it.
    private static let currentRun = UUID().uuidString

    /// A store in a new directory under the temporary directory. The directory is created with the first file.
    ///
    /// - Parameter run: The run of the program the store belongs to, this one unless said otherwise. A directory
    ///   of another run counts as left behind.
    init(parent: URL = FileManager.default.temporaryDirectory, run: String = Self.currentRun) {
        let root = parent.appendingPathComponent(Self.rootName, isDirectory: true)
        directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        ledger = CaptureDirectoryLedger(root: root, run: run)
    }

    /// Writes the photo bytes into a new file named after the capture, with the extension of its type. A file beside
    /// the photo of the capture carries a mark after the name, such as `camera` for the camera's own photo.
    ///
    /// The bytes go into a file of a name of their own first, written whole or not at all, which then takes its
    /// name: a move never replaces a file, so no photo is written over another.
    func writePhoto(_ data: Data, identifier: UUID, type: UTType, mark: String? = nil) throws -> URL {
        let url = try fileURL(identifier: identifier, type: type, mark: mark)
        let unnamedURL = directory.appendingPathComponent(".\(UUID().uuidString)").appendingPathExtension("partial")
        do {
            try data.write(to: unnamedURL, options: .atomic)
        } catch {
            throw StorageFailure.cameraError("Cannot write the photo file", cause: error)
        }
        do {
            try FileManager.default.moveItem(at: unnamedURL, to: url)
        } catch {
            Self.discard(unnamedURL)
            throw StorageFailure.cameraError("Cannot write the photo file", cause: error)
        }
        return url
    }

    /// Moves a Live Photo movie into the store, next to its photo.
    func moveMovie(from source: URL, identifier: UUID) throws -> URL {
        let url = try fileURL(identifier: identifier, type: .quickTimeMovie)
        do {
            try FileManager.default.moveItem(at: source, to: url)
        } catch {
            throw StorageFailure.cameraError("Cannot move the Live Photo movie", cause: error)
        }
        return url
    }

    /// Moves a file loaded from the photo library into the store, named after its photo, with the file name
    /// extension it came with.
    func moveLibraryPhoto(from source: URL, identifier: UUID) throws -> URL {
        let url = try fileURL(identifier: identifier, fileExtension: source.pathExtension)
        do {
            try FileManager.default.moveItem(at: source, to: url)
        } catch {
            throw StorageFailure.cameraError("Cannot move the library photo", cause: error)
        }
        return url
    }

    /// Gives a file written into the store's directory the name of a file of the capture, with its mark and the
    /// file name extension it has.
    func moveCopy(from source: URL, identifier: UUID, mark: String) throws -> URL {
        let url = try fileURL(identifier: identifier, fileExtension: source.pathExtension, mark: mark)
        do {
            try FileManager.default.moveItem(at: source, to: url)
        } catch {
            throw StorageFailure.cameraError("Cannot name the copy", cause: error)
        }
        return url
    }

    /// Deletes a file that is not handed over. A failure is logged: there is nobody to report it to.
    static func discard(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("Cannot remove a file", cause: error)
        }
    }

    /// Deletes every file of a capture: the photo, its Live Photo movie, its copy with the second camera's circle and
    /// the picture kept for the photo library.
    static func discardFiles(of capture: CameraCapture) {
        capture.fileURLs.forEach(discard)
    }

    /// A new place for a Live Photo movie, where the camera writes it before it is moved beside its photo. The
    /// movies of a run share one directory of the package, so one left behind goes with the rest.
    static func temporaryMovieURL(parent: URL = FileManager.default.temporaryDirectory) throws -> URL {
        try sharedDirectory(named: "movies", parent: parent)
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
    }

    /// The directory the rendered content of the edits for the photo library is written into before the library
    /// takes it. The edits of a run share it, so one left behind goes with the rest.
    static func temporaryEditDirectory(parent: URL = FileManager.default.temporaryDirectory) throws -> URL {
        try sharedDirectory(named: "edits", parent: parent)
    }

    /// A new place for the copy of a file picked from the photo library, with its file name extension, where it
    /// waits until its flow moves it into its store. The picks of a run share one directory of the package, so one
    /// left behind by a kill goes with the rest.
    static func temporaryPickURL(
        pathExtension: String,
        parent: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        try sharedDirectory(named: "picks", parent: parent)
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
    }

    /// A directory of the package that every flow of this run shares, entered in the ledger like a store's.
    private static func sharedDirectory(named name: String, parent: URL) throws -> URL {
        let root = parent.appendingPathComponent(rootName, isDirectory: true)
        let directory = root.appendingPathComponent("\(name)-\(currentRun)", isDirectory: true)
        try CaptureDirectoryLedger(root: root, run: currentRun).makeDirectory(at: directory)
        return directory
    }

    /// Removes the directory when nothing is left in it, and its entry in the ledger with it. Files handed over
    /// and not yet moved stay where they are.
    func removeDirectoryIfEmpty() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return }
        do {
            guard try fileManager.contentsOfDirectory(atPath: directory.path).isEmpty else { return }
            try fileManager.removeItem(at: directory)
        } catch {
            Self.logger.error("Cannot clean up the capture directory", cause: error)
            return
        }
        ledger.removeEntry(of: directory)
    }

    /// Gives the directory and what is in it to the app: its entry leaves the ledger, so no later flow removes it.
    func releaseToReceiver() {
        ledger.removeEntry(of: directory)
    }

    /// Removes the directories that earlier runs of the program left behind under the package's folder: those
    /// still entered in the ledger under another run, and the ones handed over to the app that it emptied. A
    /// directory without an entry belongs to the app and stays while it holds anything, and one entered under this
    /// run belongs to a flow that may still be open. Returns how many were removed.
    @discardableResult
    func removeStaleDirectories() -> Int {
        let removedCount = ledger.removeDirectoriesOfOtherRuns() + ledger.removeEmptyReleasedDirectories()
        if removedCount > 0 {
            Self.logger.info("Removed \(removedCount, privacy: .public) capture directories left behind")
        }
        return removedCount
    }

    private func fileURL(identifier: UUID, type: UTType, mark: String? = nil) throws -> URL {
        guard let fileExtension = type.preferredFilenameExtension else {
            throw CameraServiceError.cannotStore("The type \(type.identifier) has no file name extension")
        }
        return try fileURL(identifier: identifier, fileExtension: fileExtension, mark: mark)
    }

    /// A place in the directory for a file of a capture: its identifier, the mark after a dash when there is one,
    /// and the extension.
    private func fileURL(identifier: UUID, fileExtension: String, mark: String? = nil) throws -> URL {
        try ledger.makeDirectory(at: directory)
        let name = mark.map { "\(identifier.uuidString)-\($0)" } ?? identifier.uuidString
        return directory
            .appendingPathComponent(name)
            .appendingPathExtension(fileExtension)
    }
}
