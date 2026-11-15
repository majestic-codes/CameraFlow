//
//  LibraryPhotoPipelineTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

@Suite("Library photo pipeline", .temporaryDirectory, .timeLimit(.minutes(1)))
struct LibraryPhotoPipelineTests {
    let store = CaptureTestSupport.makeFileStore()

    @Test("A pick becomes the library's file, byte for byte, in the directory of the flow")
    func keepsFile() async throws {
        let data = try DevicePhotoFixture.make()
        let pipeline = LibraryPhotoPipeline(store: store, output: CameraFlowOutput())
        let photo = try await pipeline.process(FakeLibraryPick(data: data))
        let stored = try Data(contentsOf: photo.fileURL)
        #expect(stored == data)
        #expect(photo.fileURL.deletingLastPathComponent() == store.directory)
        #expect(photo.fileURL.lastPathComponent == "\(photo.id.uuidString).heic")
        try FileManager.default.removeItem(at: photo.fileURL)
    }

    @Test("The file keeps the extension it came with, and its type is read from its bytes")
    func extensionAndType() async throws {
        let pick = FakeLibraryPick(data: try FlowTestSupport.makeJPEG(), fileExtension: "JPG")
        let photo = try await LibraryPhotoPipeline(store: store, output: CameraFlowOutput()).process(pick)
        #expect(photo.fileURL.pathExtension == "JPG")
        #expect(photo.contentType == .jpeg)
        try FileManager.default.removeItem(at: photo.fileURL)
    }

    @Test("The thumbnail is upright and no larger than the camera's")
    func thumbnail() async throws {
        let pick = FakeLibraryPick(data: try DevicePhotoFixture.make())
        let photo = try await LibraryPhotoPipeline(store: store, output: CameraFlowOutput()).process(pick)
        #expect(photo.contentType == .heic)
        #expect(photo.thumbnail.width == DevicePhotoFixture.height)
        #expect(photo.thumbnail.height == DevicePhotoFixture.width)
        #expect(photo.thumbnail.height <= CameraCapture.thumbnailMaximumPixelSize)
        try FileManager.default.removeItem(at: photo.fileURL)
    }

    @Test("A pick without a file fails and leaves nothing behind")
    func noFile() async {
        await #expect(throws: PhotoLibraryPickError.noImageFile) {
            try await LibraryPhotoPipeline(store: store, output: CameraFlowOutput()).process(FakeLibraryPick(data: nil))
        }
        #expect(FlowTestSupport.fileExists(store.directory) == false)
    }

    @Test(
        "A pick brought to an output keeps every property and XMP tag of the library's file",
        .needsDeviceImageIO(.jpegMetadataCopy),
        arguments: [
            UTType.heic, .jpeg
        ]
    )
    func outputKeepsMetadata(type: UTType) async throws {
        let original = try FullPhotoFixture.make(type: type)
        let fileExtension = try #require(type.preferredFilenameExtension)
        let pick = FakeLibraryPick(data: original, fileExtension: fileExtension)
        let pipeline = LibraryPhotoPipeline(store: store, output: CameraFlowOutput(size: .longSide(maximum: 128)))
        let photo = try await pipeline.process(pick)
        let stored = try Data(contentsOf: photo.fileURL)
        try MetadataExpectations.expectKept(from: original, in: stored)
        for (path, value) in FullPhotoFixture.xmpTags {
            #expect(try MetadataExpectations.xmpValue(at: path, of: stored) == value, "\(path)")
        }
        try FileManager.default.removeItem(at: photo.fileURL)
    }

    // MARK: - Live Photos

    private let movie = Data("movie".utf8)

    @Test("A Live Photo keeps its movie beside its photo, under an output that keeps the metadata", arguments: [
        CameraFlowOutput(), {
            var output = CameraFlowOutput()
            output.size = .longSide(maximum: 128)
            return output
        }()
    ])
    func livePhotoMovieKept(output: CameraFlowOutput) async throws {
        let pick = FakeLibraryPick(data: try DevicePhotoFixture.make(), movieData: movie)
        let photo = try await LibraryPhotoPipeline(store: store, output: output).process(pick)
        let movieURL = try #require(photo.livePhotoMovieURL)
        #expect(try Data(contentsOf: movieURL) == movie)
        #expect(movieURL.lastPathComponent == "\(photo.id.uuidString).mov")
        #expect(movieURL.deletingLastPathComponent() == store.directory)
        #expect(Set(photo.fileURLs) == Set([photo.fileURL, movieURL]))
        photo.fileURLs.forEach(CaptureFileStore.discard)
    }

    @Test("An output that strips the metadata leaves the movie of a Live Photo out")
    func livePhotoMovieStripped() async throws {
        var output = CameraFlowOutput()
        output.metadata = .stripped
        let pick = FakeLibraryPick(data: try DevicePhotoFixture.make(), movieData: movie)
        let photo = try await LibraryPhotoPipeline(store: store, output: output).process(pick)
        #expect(photo.livePhotoMovieURL == nil)
        let stored = try FileManager.default.contentsOfDirectory(atPath: store.directory.path)
        #expect(stored == [photo.fileURL.lastPathComponent])
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: TestDirectory.current.path)
        #expect(leftovers.allSatisfy { !$0.hasSuffix(".mov") })
        try FileManager.default.removeItem(at: photo.fileURL)
    }

    @Test("A Live Photo whose photo cannot be read fails, and its movie is deleted with it")
    func livePhotoUnreadable() async throws {
        let pick = FakeLibraryPick(data: Data("not a photo".utf8), fileExtension: "jpg", movieData: movie)
        await #expect(throws: CameraServiceError.noImageData) {
            try await LibraryPhotoPipeline(store: store, output: CameraFlowOutput()).process(pick)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.directory.path).isEmpty)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: TestDirectory.current.path)
        #expect(leftovers.allSatisfy { !$0.hasSuffix(".mov") && !$0.hasSuffix(".jpg") })
    }

    // MARK: - DNG

    /// What ImageIO reads a stored photo file as.
    private struct StoredFile {
        let typeIdentifier: String?
        let width: Int?
        let height: Int?

        init(_ photo: LibraryPhoto) throws {
            let source = try #require(CGImageSourceCreateWithURL(photo.fileURL as CFURL, nil))
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            typeIdentifier = CGImageSourceGetType(source) as String?
            width = properties?[kCGImagePropertyPixelWidth] as? Int
            height = properties?[kCGImagePropertyPixelHeight] as? Int
        }
    }

    @Test("A DNG the output leaves alone is kept as it is, a DNG")
    func dngKept() async throws {
        let pick = FakeLibraryPick(data: DNGFixture.make(), fileExtension: "dng")
        let photo = try await LibraryPhotoPipeline(store: store, output: CameraFlowOutput()).process(pick)
        #expect(photo.contentType.identifier == "com.adobe.raw-image")
        #expect(try Data(contentsOf: photo.fileURL) == DNGFixture.make())
        try FileManager.default.removeItem(at: photo.fileURL)
    }

    @Test(
        "A DNG over the size limit is scaled from its RAW image into a HEIC, not from the preview it holds",
        .needsDeviceImageIO(.rawDecoding)
    )
    func dngScaled() async throws {
        let pick = FakeLibraryPick(data: DNGFixture.make(), fileExtension: "dng")
        let pipeline = LibraryPhotoPipeline(store: store, output: CameraFlowOutput(size: .longSide(maximum: 128)))
        let photo = try await pipeline.process(pick)
        #expect(photo.contentType == .heic)
        let stored = try StoredFile(photo)
        #expect(stored.typeIdentifier == UTType.heic.identifier)
        #expect(stored.width == 128)
        #expect(stored.height == 96)
        try FileManager.default.removeItem(at: photo.fileURL)
    }

    @Test(
        "A DNG under a format is encoded from its RAW image at its size",
        .needsDeviceImageIO(.rawDecoding),
        arguments: [
            (CameraFlowOutputFormat.jpeg(quality: 0.8), UTType.jpeg),
            (.heic(quality: 0.8), .heic)
        ]
    )
    func dngEncoded(format: CameraFlowOutputFormat, type: UTType) async throws {
        let pick = FakeLibraryPick(data: DNGFixture.make(), fileExtension: "dng")
        let photo = try await LibraryPhotoPipeline(store: store, output: CameraFlowOutput(format: format)).process(pick)
        #expect(photo.contentType == type)
        let stored = try StoredFile(photo)
        #expect(stored.width == DNGFixture.rawWidth)
        #expect(stored.height == DNGFixture.rawHeight)
        try FileManager.default.removeItem(at: photo.fileURL)
    }

    @Test("A file that is no photo fails and is deleted")
    func notPhoto() async throws {
        let pick = FakeLibraryPick(data: Data("not a photo".utf8), fileExtension: "jpg")
        await #expect(throws: CameraServiceError.noImageData) {
            try await LibraryPhotoPipeline(store: store, output: CameraFlowOutput()).process(pick)
        }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: store.directory.path)
        #expect(leftovers.isEmpty)
        store.removeDirectoryIfEmpty()
    }
}
