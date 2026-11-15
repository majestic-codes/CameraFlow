//
//  PhotoLibraryEditFileTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

@Suite("The rendered content of an edit for the photo library", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoLibraryEditFileTests {
    private let directory = CaptureTestSupport.makeFileStore().directory

    private var editDirectory: URL {
        directory.appendingPathComponent("Edits", isDirectory: true)
    }

    private func makeEditDirectory() throws {
        try FileManager.default.createDirectory(at: editDirectory, withIntermediateDirectories: true)
    }

    @Test("A photo is written as a JPEG of its own size with its metadata", arguments: [UTType.heic, .jpeg])
    func written(type: UTType) throws {
        let photo = try OrientedPhotoFixture.makeFile(orientation: 6, type: type, in: directory)
        try makeEditDirectory()
        let edit = try PhotoLibraryEditFile.write(photo, into: editDirectory)
        let facts = try LargePhotoFixture.facts(of: edit)
        let original = try LargePhotoFixture.facts(of: photo)
        #expect(facts.type == .jpeg)
        #expect(facts.width == original.width)
        #expect(facts.height == original.height)
        let properties = try ImageFile.properties(of: edit)
        #expect(properties[kCGImagePropertyOrientation] as? Int == 6)
        #expect(properties[kCGImagePropertyGPSDictionary] != nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: editDirectory.path).count == 1)
    }

    @Test("The JPEG keeps every property, every XMP tag and the auxiliary images of the photo", arguments: [
        UTType.heic, .jpeg
    ])
    func everythingKept(type: UTType) throws {
        try makeEditDirectory()
        let original = try FullPhotoFixture.make(type: type)
        let photo = directory.appendingPathComponent("photo").appendingPathExtension(for: type)
        try original.write(to: photo)
        let editURL = try PhotoLibraryEditFile.write(photo, into: editDirectory)
        let edit = try Data(contentsOf: editURL)
        try MetadataExpectations.expectKept(from: original, in: edit)
        for (path, value) in FullPhotoFixture.xmpTags {
            #expect(try MetadataExpectations.xmpValue(at: path, of: edit) == value, "\(path)")
        }
        let source = try #require(CGImageSourceCreateWithData(edit as CFData, nil))
        for auxiliaryType in [kCGImageAuxiliaryDataTypeHDRGainMap, kCGImageAuxiliaryDataTypePortraitEffectsMatte] {
            #expect(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, auxiliaryType) != nil, "\(auxiliaryType)")
        }
    }

    @Test("A photo that cannot be read fails before anything is written", arguments: UnreadablePhotoFile.allCases)
    func unreadable(file: UnreadablePhotoFile) throws {
        try makeEditDirectory()
        let photo = try file.url(in: directory, fileExtension: "heic")
        #expect(throws: PhotoLibraryEditFailure.self) {
            try PhotoLibraryEditFile.write(photo, into: editDirectory)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: editDirectory.path).isEmpty)
    }

    @Test("A photo fails when its JPEG cannot be written, and nothing is left behind")
    func unwritable() throws {
        let photo = try OrientedPhotoFixture.makeFile(orientation: 1, type: .jpeg, in: directory)
        let noDirectory = directory.appendingPathComponent("Missing", isDirectory: true)
        #expect(throws: PhotoLibraryEditFailure.self) {
            try PhotoLibraryEditFile.write(photo, into: noDirectory)
        }
        #expect(FileManager.default.fileExists(atPath: noDirectory.path) == false)
    }
}
