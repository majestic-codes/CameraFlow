//
//  CaptureDirectoryLedger.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import os

/// The record of the directories the package made and still owns, kept beside them in the package's folder: an
/// empty file named after each directory, in a folder named after the run of the program that made it.
///
/// The entry is what tells a directory the package still owns from one whose files went to the app. A directory
/// still entered under an earlier run was left behind by a crash or a kill.
struct CaptureDirectoryLedger: Sendable {
    /// The folder of the package, which holds the directories and the ledger.
    let root: URL
    /// The run of the program the entries are made under.
    let run: String

    private static let logger = Logger.camera("CaptureDirectoryLedger")
    private static let folderName = ".runs"

    private var folder: URL {
        root.appendingPathComponent(Self.folderName, isDirectory: true)
    }

    private func entry(of directory: URL) -> URL {
        folder
            .appendingPathComponent(run, isDirectory: true)
            .appendingPathComponent(directory.lastPathComponent)
    }

    /// Makes a directory of the package and enters it under the run. A directory that is already there is left as
    /// it is: one released to the app is not entered again.
    func makeDirectory(at directory: URL) throws(CameraServiceError) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: directory.path) else { return }
        let entry = entry(of: directory)
        do {
            try fileManager.createDirectory(at: entry.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: entry)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw StorageFailure.cameraError("Cannot create the capture directory", cause: error)
        }
    }

    /// Takes the entry of a directory out, so no later run removes the directory. An entry that cannot be removed
    /// is logged, and its directory then goes with a later run.
    func removeEntry(of directory: URL) {
        let entry = entry(of: directory)
        guard FileManager.default.fileExists(atPath: entry.path) else { return }
        do {
            try FileManager.default.removeItem(at: entry)
        } catch {
            Self.logger.error("Cannot take the capture directory out of the ledger", cause: error)
        }
    }

    /// Removes the directories still entered under another run, with their entries, and returns how many were
    /// removed. What cannot be read or removed is logged and left for the next time, and the rest still goes.
    func removeDirectoriesOfOtherRuns() -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: folder.path) else { return 0 }
        let runs: [String]
        do {
            runs = try fileManager.contentsOfDirectory(atPath: folder.path)
        } catch {
            Self.logger.error("Cannot read the ledger", cause: error)
            return 0
        }
        return runs.filter { $0 != run }.reduce(0) { removedCount, otherRun in
            removedCount + removeDirectories(ofRun: otherRun)
        }
    }

    /// Removes the directories under the package's folder that no run has entered and that hold nothing: a
    /// directory handed over to the app, which moved its files out. The package's folder is listed before the
    /// ledger is read, and a directory is entered before it is made, so a directory that is being made is never
    /// taken for a released one. Returns how many were removed.
    func removeEmptyReleasedDirectories() -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: folder.path) else { return 0 }
        let names: [String]
        let runs: [String]
        do {
            names = try fileManager.contentsOfDirectory(atPath: root.path)
            runs = try fileManager.contentsOfDirectory(atPath: folder.path)
        } catch {
            Self.logger.error("Cannot read the package's folder", cause: error)
            return 0
        }
        var entered: Set<String> = [Self.folderName]
        for otherRun in runs {
            let entries = folder.appendingPathComponent(otherRun, isDirectory: true)
            do {
                entered.formUnion(try fileManager.contentsOfDirectory(atPath: entries.path))
            } catch {
                Self.logger.error("Cannot read the entries of a run, its directories stay", cause: error)
                return 0
            }
        }
        return names.filter { !entered.contains($0) }.count { name in
            // rmdir removes nothing but an empty directory, so a file that arrives meanwhile keeps it.
            rmdir(root.appendingPathComponent(name, isDirectory: true).path) == 0
        }
    }

    /// Removes the directories entered under a run, and the folder of the run once all of them are gone.
    private func removeDirectories(ofRun otherRun: String) -> Int {
        let fileManager = FileManager.default
        let entries = folder.appendingPathComponent(otherRun, isDirectory: true)
        let names: [String]
        do {
            names = try fileManager.contentsOfDirectory(atPath: entries.path)
        } catch {
            Self.logger.error("Cannot read the entries of an earlier run", cause: error)
            return 0
        }
        var removedCount = 0
        var failedCount = 0
        for name in names {
            let leftBehind = root.appendingPathComponent(name, isDirectory: true)
            do {
                if fileManager.fileExists(atPath: leftBehind.path) {
                    try fileManager.removeItem(at: leftBehind)
                    removedCount += 1
                }
                try fileManager.removeItem(at: entries.appendingPathComponent(name))
            } catch {
                failedCount += 1
                Self.logger.error("Cannot remove a capture directory left behind", cause: error)
            }
        }
        guard failedCount == 0 else { return removedCount }
        do {
            try fileManager.removeItem(at: entries)
        } catch {
            Self.logger.error("Cannot remove the entries of an earlier run", cause: error)
        }
        return removedCount
    }
}
