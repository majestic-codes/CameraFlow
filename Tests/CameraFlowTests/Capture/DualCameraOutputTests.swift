//
//  DualCameraOutputTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// A dual capture of the device's HEIF, with a location, through the output of the flow.
@MainActor
@Suite("Output: the copy with the second camera's circle", .temporaryDirectory, .timeLimit(.minutes(1)))
struct DualCameraOutputTests {
    private let store = CaptureTestSupport.makeFileStore()

    private func process(
        with output: CameraFlowOutput,
        photoData: Data? = nil,
        keepsLibraryPicture: Bool = true
    ) async throws -> CameraCapture {
        let frameData = try DevicePhotoFixture.make()
        let frame = CircleCameraFrame(imageData: frameData, isViewfinderMirrored: false, viewfinderQuarterTurns: 0)
        let photoData = try photoData ?? DevicePhotoFixture.makeCameraFile()
        let photo = CapturedPhoto(
            imageData: photoData,
            encoding: .heif,
            livePhotoMovieURL: nil,
            location: LocationFixture.location(latitude: -33.86, longitude: 151.21),
            circleCameraFrame: frame
        )
        let pipeline = PhotoCapturePipeline(
            aspectRatio: .fourByThree,
            output: output,
            store: store,
            dualCameraCircle: DualCameraFixture.circleOnScreen,
            keepsLibraryPicture: keepsLibraryPicture
        )
        return try await pipeline.process(photo)
    }

    private func storedFileNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: store.directory.path).sorted()
    }

    @Test("With the default output the copy is the full picture with its metadata, and the library takes it")
    func defaultOutput() async throws {
        let capture = try await process(with: CameraFlowOutput())
        let copyURL = try #require(capture.dualCameraCopy?.url)
        #expect(capture.libraryFileURL == nil)
        #expect(try ImageFile.contentType(of: copyURL) == .heic)
        #expect(capture.dualCameraCopy?.contentType == .heic)
        let copy = try ImageFile.properties(of: copyURL)
        #expect(copy[kCGImagePropertyPixelWidth] as? Int == DevicePhotoFixture.height)
        #expect(copy[kCGImagePropertyGPSDictionary] != nil)
        #expect(try storedFileNames().count == 2)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("Under an output in a flow that never saves, the copy in the output is the only copy")
    func changedOutputWithoutLibraryPicture() async throws {
        var output = CameraFlowOutput()
        output.size = .longSide(maximum: 128)
        let capture = try await process(with: output, keepsLibraryPicture: false)
        let copyURL = try #require(capture.dualCameraCopy?.url)
        #expect(capture.libraryFileURL == nil)
        #expect(try ImageFile.properties(of: copyURL)[kCGImagePropertyPixelHeight] as? Int == 128)
        #expect(try storedFileNames() == [capture.fileURL, copyURL].map(\.lastPathComponent).sorted())
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("Under an output the copy is brought to it like the photo, and the library keeps the full copy")
    func changedOutput() async throws {
        var output = CameraFlowOutput()
        output.size = .longSide(maximum: 128)
        output.format = .jpeg(quality: 0.8)
        output.metadata = .stripped
        let capture = try await process(with: output)
        let copyURL = try #require(capture.dualCameraCopy?.url)
        let libraryURL = try #require(capture.libraryFileURL)
        #expect(copyURL.lastPathComponent == "\(capture.id.uuidString)-dual.jpeg")
        #expect(try ImageFile.contentType(of: capture.fileURL) == .jpeg)
        #expect(try ImageFile.contentType(of: copyURL) == .jpeg)
        #expect(capture.dualCameraCopy?.contentType == .jpeg)
        let copy = try ImageFile.properties(of: copyURL)
        #expect(copy[kCGImagePropertyPixelWidth] as? Int == 96)
        #expect(copy[kCGImagePropertyPixelHeight] as? Int == 128)
        #expect(copy[kCGImagePropertyGPSDictionary] == nil)
        if let copyExif = copy[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            #expect(copyExif[kCGImagePropertyExifLensModel] == nil)
        }
        #expect(try ImageFile.contentType(of: libraryURL) == .heic)
        let library = try ImageFile.properties(of: libraryURL)
        #expect(library[kCGImagePropertyPixelWidth] as? Int == DevicePhotoFixture.height)
        #expect(library[kCGImagePropertyPixelHeight] as? Int == DevicePhotoFixture.width)
        let gps = try #require(library[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        #expect(gps[kCGImagePropertyGPSLatitudeRef] as? String == "S")
        let exif = try #require(library[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifLensModel] as? String == DevicePhotoFixture.lensModel)
        let names = try storedFileNames()
        #expect(names.count == 3)
        #expect(names.contains { $0.contains("-camera.") } == false, "The camera's photo is left: \(names)")
        try CaptureTestSupport.discardFiles(of: capture)
        #expect(try storedFileNames().isEmpty)
    }

    @Test("Under an output the copy is encoded once, from the camera's photo: at 1 it is as close to it as the photo")
    func encodedOnce() async throws {
        let cameraData = try LargePhotoFixture.heic.get()
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let cameraPhoto = store.directory.appendingPathComponent("camera-photo.heic")
        try cameraData.write(to: cameraPhoto)
        var best = CameraFlowOutput()
        best.format = .jpeg(quality: 1)
        var good = CameraFlowOutput()
        good.format = .jpeg(quality: 0.9)
        let bestCapture = try await process(with: best, photoData: cameraData)
        let goodCapture = try await process(with: good, photoData: cameraData)
        let bestCopy = try #require(bestCapture.dualCameraCopy?.url)
        let goodCopy = try #require(goodCapture.dualCameraCopy?.url)
        let facts = try LargePhotoFixture.facts(of: bestCopy)
        #expect(facts.type == .jpeg)
        #expect(facts.width == LargePhotoFixture.width)
        #expect(facts.height == LargePhotoFixture.height)
        let belowCircle = LargePhotoFixture.height / 2
        let bestDistance = try PixelGrid.distance(from: bestCopy, to: cameraPhoto, firstRow: belowCircle)
        let goodDistance = try PixelGrid.distance(from: goodCopy, to: cameraPhoto, firstRow: belowCircle)
        let photoDistance = try PixelGrid.distance(from: bestCapture.fileURL, to: cameraPhoto, firstRow: belowCircle)
        let comment = Comment("\(bestDistance) at 1, \(goodDistance) at 0.9, \(photoDistance) for the photo at 1")
        #expect(bestDistance * 2 < goodDistance, comment)
        #expect(bestDistance <= photoDistance * 1.5 + 0.5, comment)
        try CaptureTestSupport.discardFiles(of: bestCapture)
        try CaptureTestSupport.discardFiles(of: goodCapture)
    }
}
