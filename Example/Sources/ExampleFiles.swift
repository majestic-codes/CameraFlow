//
//  ExampleFiles.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import os

/// The photo files the example keeps in its Documents folder during one launch: the photos of the flow and their
/// copies with a drawing. Each launch starts without the files of the one before.
enum ExampleFiles {
    private static let capturesName = "Captures"
    private static let editedName = "Edited"
    private static let logger = Logger(subsystem: "CameraFlowExample", category: "Files")

    /// `Documents/Captures`, where the example moves every photo it takes over.
    static func capturesDirectory() throws -> URL {
        try directory(named: capturesName)
    }

    /// Moves a file into a directory under its own name and returns where it is now.
    static func move(_ file: URL, into directory: URL) throws -> URL {
        let destination = directory.appendingPathComponent(file.lastPathComponent)
        try FileManager.default.moveItem(at: file, to: destination)
        return destination
    }

    /// Moves an edited copy into `Documents/Edited` under the original's name, numbered so nothing already kept is
    /// overwritten, and returns where it is now.
    static func moveEditedCopy(at editedCopy: URL, of original: URL) throws -> URL {
        let stem = original.deletingPathExtension().lastPathComponent
        let edited = try directory(named: editedName)
        let destination = freeURL(in: edited, stem: "\(stem)-edited", pathExtension: editedCopy.pathExtension)
        try FileManager.default.moveItem(at: editedCopy, to: destination)
        return destination
    }

    /// Removes the files that exist among the given ones. A file that cannot be removed is logged.
    static func remove(_ files: [URL]) {
        for file in files where FileManager.default.fileExists(atPath: file.path) {
            do {
                try FileManager.default.removeItem(at: file)
            } catch {
                let reason = String(describing: error)
                logger.error("Cannot remove \(file.lastPathComponent, privacy: .public): \(reason, privacy: .public)")
            }
        }
    }

    /// Removes `Documents/Captures` and `Documents/Edited` with everything in them.
    static func removeAll() throws {
        let documents = try documentsDirectory()
        for name in [capturesName, editedName] {
            let directory = documents.appendingPathComponent(name, isDirectory: true)
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }
            try FileManager.default.removeItem(at: directory)
        }
    }

    private static func freeURL(in directory: URL, stem: String, pathExtension: String) -> URL {
        var number = 1
        var candidate: URL
        repeat {
            candidate = directory.appendingPathComponent("\(stem)-\(number)").appendingPathExtension(pathExtension)
            number += 1
        } while FileManager.default.fileExists(atPath: candidate.path)
        return candidate
    }

    private static func directory(named name: String) throws -> URL {
        let directory = try documentsDirectory().appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func documentsDirectory() throws -> URL {
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}
