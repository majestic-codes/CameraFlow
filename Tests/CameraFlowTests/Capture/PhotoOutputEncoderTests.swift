//
//  PhotoOutputEncoderTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// The output of the flow applied to the device's HEIF: stored landscape 256 x 192 with the portrait tag, EXIF,
/// TIFF, GPS, XMP and a gain map.
@Suite("Output: size, format and metadata of a photo", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoOutputEncoderTests {

    private func xmpLabel(of data: Data) throws -> String? {
        try MetadataExpectations.xmpValue(at: DevicePhotoFixture.xmpPath as String, of: data)
    }

    @Test("The default output leaves a file as it is, readable or not")
    func untouched() throws {
        let encoder = PhotoOutputEncoder(output: CameraFlowOutput())
        let photo = try DevicePhotoFixture.make()
        #expect(try encoder.encode(photo) == nil)
        #expect(try encoder.encode(Data("not a photo".utf8)) == nil)
    }

    @Test("A photo within the size limit is left as it is")
    func withinLimit() throws {
        let encoder = PhotoOutputEncoder(output: CameraFlowOutput(size: .longSide(maximum: 256)))
        let photo = try DevicePhotoFixture.make()
        #expect(try encoder.encode(photo) == nil)
    }

    @Test("A photo above the size limit is scaled in its own format with its metadata, orientation and gain map")
    func scaled() throws {
        let encoder = PhotoOutputEncoder(output: CameraFlowOutput(size: .longSide(maximum: 128)))
        let photo = try DevicePhotoFixture.make()
        let encoded = try #require(try encoder.encode(photo))
        #expect(encoded.type == .heic)
        let properties = try DevicePhotoFixture.properties(of: encoded.data)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 128)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 96)
        #expect(properties[kCGImagePropertyOrientation] as? Int == DevicePhotoFixture.orientation)
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifLensModel] as? String == DevicePhotoFixture.lensModel)
        let gps = try #require(properties[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        #expect(gps[kCGImagePropertyGPSLatitude] as? Double == DevicePhotoFixture.latitude)
        #expect(try xmpLabel(of: encoded.data) == DevicePhotoFixture.xmpValue)
        #expect(exif[kCGImagePropertyExifPixelXDimension] as? Int == 128)
        #expect(exif[kCGImagePropertyExifPixelYDimension] as? Int == 96)
        let gainMap = try DevicePhotoFixture.gainMap(of: encoded.data)
        #expect(gainMap.width == 64)
        #expect(gainMap.height == 48)
    }

    @Test("A JPEG is asked for at its quality, with the metadata and the gain map kept", arguments: [0.3, 0.95])
    func jpeg(quality: Double) throws {
        let encoder = PhotoOutputEncoder(output: CameraFlowOutput(format: .jpeg(quality: quality)))
        let photo = try DevicePhotoFixture.make()
        let encoded = try #require(try encoder.encode(photo))
        #expect(encoded.type == .jpeg)
        #expect(try ImageFile.contentType(of: encoded.data) == .jpeg)
        let properties = try DevicePhotoFixture.properties(of: encoded.data)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == DevicePhotoFixture.width)
        #expect(properties[kCGImagePropertyOrientation] as? Int == DevicePhotoFixture.orientation)
        #expect(properties[kCGImagePropertyGPSDictionary] != nil)
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifLensModel] as? String == DevicePhotoFixture.lensModel)
        #expect(try xmpLabel(of: encoded.data) == DevicePhotoFixture.xmpValue)
        let gainMap = try DevicePhotoFixture.gainMap(of: encoded.data)
        #expect(gainMap.width == DevicePhotoFixture.width / 2)
        #expect(gainMap.hasVersionTag)
    }

    @Test("A lower quality makes a smaller JPEG")
    func qualityMatters() throws {
        let photo = try DevicePhotoFixture.make()
        let smallEncoder = PhotoOutputEncoder(output: CameraFlowOutput(format: .jpeg(quality: 0.2)))
        let largeEncoder = PhotoOutputEncoder(output: CameraFlowOutput(format: .jpeg(quality: 1)))
        let small = try #require(try smallEncoder.encode(photo))
        let large = try #require(try largeEncoder.encode(photo))
        #expect(small.data.count < large.data.count)
    }

    @Test("A HEIC is encoded again even when the photo is one already")
    func heic() throws {
        let encoder = PhotoOutputEncoder(output: CameraFlowOutput(format: .heic(quality: 0.5)))
        let photo = try DevicePhotoFixture.make()
        let encoded = try #require(try encoder.encode(photo))
        #expect(encoded.type == .heic)
        #expect(encoded.data != photo)
        #expect(try ImageFile.contentType(of: encoded.data) == .heic)
        #expect(try xmpLabel(of: encoded.data) == DevicePhotoFixture.xmpValue)
    }

    @Test("Stripped metadata leaves the upright pixels, their size and profile, and nothing about the shot")
    func stripped() throws {
        let encoder = PhotoOutputEncoder(output: CameraFlowOutput(metadata: .stripped))
        let photo = try DevicePhotoFixture.make()
        let encoded = try #require(try encoder.encode(photo))
        #expect(encoded.type == .heic)
        let properties = try DevicePhotoFixture.properties(of: encoded.data)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == DevicePhotoFixture.height)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == DevicePhotoFixture.width)
        #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(properties[kCGImagePropertyMakerAppleDictionary] == nil)
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        #expect(exif[kCGImagePropertyExifLensModel] == nil)
        #expect(exif[kCGImagePropertyExifDateTimeOriginal] == nil)
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        #expect(tiff[kCGImagePropertyTIFFMake] == nil)
        #expect(properties[kCGImagePropertyProfileName] != nil)
        let source = try #require(CGImageSourceCreateWithData(encoded.data as CFData, nil))
        #expect(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeHDRGainMap) == nil)
        let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil)
        let xmpLabel = metadata.flatMap { CGImageMetadataCopyTagWithPath($0, nil, DevicePhotoFixture.xmpPath) }
        #expect(xmpLabel == nil)
    }

    @Test("Size, format and stripping combine")
    func combined() throws {
        let encoder = PhotoOutputEncoder(
            output: CameraFlowOutput(size: .longSide(maximum: 64), format: .jpeg(quality: 0.7), metadata: .stripped)
        )
        let photo = try DevicePhotoFixture.make()
        let encoded = try #require(try encoder.encode(photo))
        #expect(encoded.type == .jpeg)
        let properties = try DevicePhotoFixture.properties(of: encoded.data)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 48)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 64)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
    }

    private static let typeCases: [(UTType?, UTType)] = [
        (.jpeg, .jpeg), (.heic, .heic), (.png, .png), (.tiff, .tiff), (.gif, .heic),
        (UTType("com.adobe.raw-image"), .heic), (nil, .heic)
    ]

    @Test("The original format keeps a type ImageIO writes and makes a HEIC of any other", arguments: typeCases)
    func outputType(sourceType: UTType?, expected: UTType) {
        let encoder = PhotoOutputEncoder(output: CameraFlowOutput(size: .standard))
        #expect(encoder.outputType(forSourceType: sourceType) == expected)
        let jpegEncoder = PhotoOutputEncoder(output: CameraFlowOutput(format: .jpeg(quality: 1)))
        #expect(jpegEncoder.outputType(forSourceType: sourceType) == .jpeg)
    }

    @Test(
        "The medium and low qualities keep every property and XMP tag of a 12 MP camera photo",
        arguments: [CameraFlowQuality.medium, .low]
    )
    func qualityKeepsMetadata(quality: CameraFlowQuality) throws {
        let photo = try FullPhotoFixture.make(width: 4_032, height: 3_024)
        let encoder = PhotoOutputEncoder(output: quality.output(within: CameraFlowOutput()))
        let encoded = try #require(try encoder.encode(photo))
        let properties = try DevicePhotoFixture.properties(of: encoded.data)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 1_920)
        try MetadataExpectations.expectKept(from: photo, in: encoded.data)
        for (path, value) in FullPhotoFixture.xmpTags {
            #expect(try MetadataExpectations.xmpValue(at: path, of: encoded.data) == value, "\(path)")
        }
    }

    @Test("Something that is no photo cannot be brought to an output")
    func unreadable() {
        let encoder = PhotoOutputEncoder(output: CameraFlowOutput(size: .standard))
        #expect(throws: PhotoOutputFailure.unreadablePhoto) {
            try encoder.encode(Data("not a photo".utf8))
        }
    }

    // MARK: - The pipeline

    @Test("A capture under an output comes as two files: the output, and the camera's photo for the library")
    func captureFiles() async throws {
        let store = CaptureTestSupport.makeFileStore()
        let original = try DevicePhotoFixture.make()
        let photo = CapturedPhoto(imageData: original, encoding: .heif, livePhotoMovieURL: nil)
        let jpegOutput = CameraFlowOutput(format: .jpeg(quality: 0.8))
        let pipeline = PhotoCapturePipeline(aspectRatio: .fourByThree, output: jpegOutput, store: store)
        let capture = try await pipeline.process(photo)
        #expect(capture.contentType == .jpeg)
        #expect(capture.fileURL.lastPathComponent == "\(capture.id.uuidString).jpeg")
        let libraryFileURL = try #require(capture.libraryFileURL)
        #expect(libraryFileURL.lastPathComponent == "\(capture.id.uuidString)-camera.heic")
        #expect(try Data(contentsOf: libraryFileURL) == original)
        #expect(try ImageFile.contentType(of: capture.fileURL) == .jpeg)
        #expect(try capture.uprightPixelSize() == CGSize(width: 192, height: 256))
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A capture under an output in a flow that never saves comes as the output alone")
    func captureWithoutLibraryPicture() async throws {
        let store = CaptureTestSupport.makeFileStore()
        let photo = CapturedPhoto(imageData: try DevicePhotoFixture.make(), encoding: .heif, livePhotoMovieURL: nil)
        let jpegOutput = CameraFlowOutput(format: .jpeg(quality: 0.8))
        var pipeline = PhotoCapturePipeline(aspectRatio: .fourByThree, output: jpegOutput, store: store)
        pipeline.keepsLibraryPicture = false
        let capture = try await pipeline.process(photo)
        #expect(capture.libraryFileURL == nil)
        #expect(capture.contentType == .jpeg)
        let stored = try FileManager.default.contentsOfDirectory(atPath: store.directory.path)
        #expect(stored == [capture.fileURL.lastPathComponent])
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A RAW photo passes the output untouched")
    func rawCapture() async throws {
        let store = CaptureTestSupport.makeFileStore()
        let original = try DevicePhotoFixture.make()
        let photo = CapturedPhoto(imageData: original, encoding: .appleProRAW, livePhotoMovieURL: nil)
        let output = CameraFlowOutput(size: .standard)
        let pipeline = PhotoCapturePipeline(aspectRatio: .fourByThree, output: output, store: store)
        let capture = try await pipeline.process(photo)
        #expect(capture.libraryFileURL == nil)
        #expect(try Data(contentsOf: capture.fileURL) == original)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test(
        "A RAW photo is a DNG with its RAW size, though its bytes alone read as the TIFF of its preview",
        .needsDeviceImageIO(.rawDecoding)
    )
    func rawCaptureType() async throws {
        let store = CaptureTestSupport.makeFileStore()
        let original = DNGFixture.make()
        let photo = CapturedPhoto(imageData: original, encoding: .appleProRAW, livePhotoMovieURL: nil)
        let output = CameraFlowOutput(size: .standard)
        let pipeline = PhotoCapturePipeline(aspectRatio: .square, output: output, store: store)
        let capture = try await pipeline.process(photo)
        #expect(capture.contentType.identifier == "com.adobe.raw-image")
        #expect(capture.fileURL.pathExtension == "dng")
        #expect(try capture.uprightPixelSize() == CGSize(width: DNGFixture.rawWidth, height: DNGFixture.rawHeight))
        #expect(capture.framedRegion == CGRect(x: 0.125, y: 0, width: 0.75, height: 1))
        #expect(try Data(contentsOf: capture.fileURL) == original)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A library pick is brought to the output, and the loaded file goes")
    func libraryPick() async throws {
        let store = CaptureTestSupport.makeFileStore()
        let pipeline = LibraryPhotoPipeline(store: store, output: CameraFlowOutput(size: .longSide(maximum: 20)))
        let pick = FakeLibraryPick(data: try FlowTestSupport.makeJPEG(), fileExtension: "jpg")
        let photo = try await pipeline.process(pick)
        #expect(photo.contentType == .jpeg)
        #expect(photo.fileURL.pathExtension == "jpeg")
        #expect(photo.fileURL.deletingLastPathComponent() == store.directory)
        let properties = try ImageFile.properties(of: photo.fileURL)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 20)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 15)
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.directory.path).count == 1)
        try FileManager.default.removeItem(at: photo.fileURL)
    }
}
