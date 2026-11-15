//
//  DamagedPhotoTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// A pick whose file is gone by the time the flow reads it.
private struct VanishedLibraryPick: PhotoLibraryPick {

    func loadFiles() async throws -> LibraryPickFiles {
        let photoURL = TestDirectory.current.appendingPathComponent("vanished-\(UUID().uuidString).heic")
        return LibraryPickFiles(photoURL: photoURL, livePhotoMovieURL: nil)
    }
}

/// Photo files the flow cannot work with as usual: cut short, missing, of a type ImageIO reads and does not write,
/// or with depth data that cannot be cropped. Each one fails with its own error or is handed over untouched, and
/// nothing is left behind.
@Suite("Photo files that are damaged, missing or cannot be changed", .temporaryDirectory, .timeLimit(.minutes(1)))
struct DamagedPhotoTests {
    private let directory = CaptureTestSupport.makeFileStore().directory

    /// A JPEG cut in half: ImageIO names its type and its image, and cannot read its size or its pixels.
    private func makeTruncatedJPEG() throws -> Data {
        let jpeg = try FlowTestSupport.makeJPEG()
        return jpeg.prefix(jpeg.count / 2)
    }

    private func write(_ data: Data, named name: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    private var missingFile: URL {
        directory.appendingPathComponent("missing.heic")
    }

    private func filesLeft() throws -> [String] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: directory.path)
    }

    // MARK: - Reading

    @Test("A preview of a file that is missing or cut short is refused")
    func preview() throws {
        let jpeg = try makeTruncatedJPEG()
        let truncated = try write(jpeg, named: "truncated.jpg")
        #expect(throws: CameraServiceError.noImageData) {
            _ = try PhotoFilePreview(url: missingFile)
        }
        #expect(throws: CameraServiceError.noImageData) {
            _ = try PhotoFilePreview(url: truncated)
        }
    }

    @Test("The size and the type of bytes that are no photo are refused, and a photo cut short still has its type")
    func sizeAndType() throws {
        let truncated = try makeTruncatedJPEG()
        #expect(throws: CameraServiceError.noImageData) {
            _ = try PhotoFilePreview.uprightSize(of: Data())
        }
        #expect(throws: CameraServiceError.noImageData) {
            _ = try PhotoFilePreview.contentType(of: Data())
        }
        #expect(throws: CameraServiceError.noImageData) {
            _ = try PhotoFilePreview.contentType(of: Data("not a photo".utf8))
        }
        #expect(throws: CameraServiceError.noImageData) {
            _ = try PhotoFilePreview.uprightSize(of: truncated)
        }
        #expect(try PhotoFilePreview.contentType(of: truncated) == .jpeg)
    }

    @Test("A picture for the screen of a missing file is refused")
    func screenImage() async {
        await #expect(throws: CameraServiceError.noImageData) {
            _ = try await PhotoScreenImage.decode(url: missingFile, maximumPixelSize: 100)
        }
    }

    // MARK: - Output

    @Test(
        "A photo cut short cannot be brought to an output that scales or strips it",
        arguments: [CameraFlowOutput(size: .longSide(maximum: 16)), CameraFlowOutput(metadata: .stripped)]
    )
    func output(output: CameraFlowOutput) throws {
        let truncated = try makeTruncatedJPEG()
        #expect(throws: PhotoOutputFailure.unreadablePhoto) {
            _ = try PhotoOutputEncoder(output: output).encode(truncated)
        }
    }

    @Test("A pick whose file is gone fails as unreadable under an output that reads it, and leaves nothing behind")
    func vanishedPick() async throws {
        let store = CaptureTestSupport.makeFileStore()
        var scaling = CameraFlowOutput()
        scaling.size = .longSide(maximum: 16)
        let pipeline = LibraryPhotoPipeline(store: store, output: scaling)
        await #expect(throws: PhotoOutputFailure.unreadablePhoto) {
            _ = try await pipeline.process(VanishedLibraryPick())
        }
        #expect(FileManager.default.fileExists(atPath: store.directory.path) == false)
    }

    @Test("A pick whose file is gone fails to be moved under the default output, which never reads it")
    func vanishedPickUnread() async throws {
        let store = CaptureTestSupport.makeFileStore()
        let pipeline = LibraryPhotoPipeline(store: store, output: CameraFlowOutput())
        await #expect {
            _ = try await pipeline.process(VanishedLibraryPick())
        } throws: { error in
            guard case let .cannotStore(reason) = error as? CameraServiceError else { return false }
            return reason.hasPrefix("Cannot move the library photo")
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.directory.path).isEmpty)
    }

    // MARK: - Copies

    @Test("A copy of a photo cut short is refused as unreadable, and nothing is written")
    func markedUpCopy() async throws {
        let jpeg = try makeTruncatedJPEG()
        let truncated = try write(jpeg, named: "truncated.jpg")
        let copies = directory.appendingPathComponent("Copies", isDirectory: true)
        await #expect(throws: OverlayCopyFailure.unreadablePhoto(truncated)) {
            _ = try await OverlayPhotoWriter.writeCopy(of: truncated, into: copies, label: "markup") { _, _ in }
        }
        #expect(FileManager.default.fileExists(atPath: copies.path) == false)
    }

    @Test("A copy for a directory that takes no file is reported, and the directory stays empty")
    func unwritableCopyDirectory() async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: 1, type: .jpeg, in: directory)
        let copies = directory.appendingPathComponent("Copies", isDirectory: true)
        try FileManager.default.createDirectory(at: copies, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: copies.path)
        await #expect {
            _ = try await OverlayPhotoWriter.writeCopy(of: original, into: copies, label: "markup") { _, _ in }
        } throws: { error in
            guard case .cannotStore = error as? OverlayCopyFailure else { return false }
            return true
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: copies.path)
        #expect(try FileManager.default.contentsOfDirectory(atPath: copies.path).isEmpty)
    }

    @Test("A copy leaves nothing but itself in its directory")
    func copyLeavesOnlyItself() async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: 1, type: .jpeg, in: directory)
        let copies = directory.appendingPathComponent("Copies", isDirectory: true)
        let copy = try await OverlayPhotoWriter.writeCopy(of: original, into: copies, label: "markup") { _, _ in }
        #expect(try FileManager.default.contentsOfDirectory(atPath: copies.path) == [copy.lastPathComponent])
        #expect(copy.lastPathComponent == "photo-markup-1.jpeg")
    }

    @Test("The photo for the library of a photo cut short is refused, and nothing stays in the directory")
    func libraryEdit() throws {
        let jpeg = try makeTruncatedJPEG()
        let truncated = try write(jpeg, named: "truncated.jpg")
        let edits = directory.appendingPathComponent("Edits", isDirectory: true)
        try FileManager.default.createDirectory(at: edits, withIntermediateDirectories: true)
        #expect {
            _ = try PhotoLibraryEditFile.write(truncated, into: edits)
        } throws: { error in
            let reason = (error as? PhotoLibraryEditFailure)?.reason
            return reason?.hasPrefix("The photo with the drawing cannot be written as a JPEG") == true
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: edits.path).isEmpty)
    }

    @Test(
        "A frame of the circle that is empty or cut short stops the copy",
        arguments: [
            (false, "The frame of the circle cannot be read"),
            (true, "The frame of the circle has no size")
        ]
    )
    func circleFrame(isTruncated: Bool, failure: String) async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: 1, type: .jpeg, in: directory)
        let frame = CircleCameraFrame(
            imageData: isTruncated ? try makeTruncatedJPEG() : Data(),
            isViewfinderMirrored: false,
            viewfinderQuarterTurns: 0
        )
        let region = CGRect(x: 0.6, y: 0.05, width: 0.3, height: 0.225)
        let composition = DualCameraPhotoWriter.Composition(
            frame: frame,
            circle: DualCameraFixture.circle(region: region),
            framedRegion: nil
        )
        let copies = directory.appendingPathComponent("Copies", isDirectory: true)
        await #expect(throws: CameraServiceError.captureFailed(failure)) {
            _ = try await DualCameraPhotoWriter.writeCopy(of: original, composition: composition, into: copies)
        }
        #expect(FileManager.default.fileExists(atPath: copies.path) == false)
    }

    @Test("A copy with the circle of a photo cut short fails as a capture that names its file, and nothing is written")
    func circleCopyOfDamagedPhoto() async throws {
        let jpeg = try makeTruncatedJPEG()
        let truncated = try write(jpeg, named: "truncated.jpg")
        let frame = try DualCameraFixture.makeCircleFrame(
            uprightSize: (60, 80),
            orientation: 1,
            viewfinderQuarterTurns: 0
        )
        let region = CGRect(x: 0.6, y: 0.05, width: 0.3, height: 0.225)
        let composition = DualCameraPhotoWriter.Composition(
            frame: frame,
            circle: DualCameraFixture.circle(region: region),
            framedRegion: nil
        )
        let copies = directory.appendingPathComponent("Copies", isDirectory: true)
        let failure = "The copy with the circle cannot be written: The photo truncated.jpg cannot be read"
        await #expect(throws: CameraServiceError.captureFailed(failure)) {
            _ = try await DualCameraPhotoWriter.writeCopy(of: truncated, composition: composition, into: copies)
        }
        #expect(FileManager.default.fileExists(atPath: copies.path) == false)
    }

    // MARK: - Crop

    @Test("A photo cut short cannot be cropped")
    func cropTruncated() throws {
        let truncated = try makeTruncatedJPEG()
        #expect(throws: CameraServiceError.cannotCrop("The photo has no readable properties")) {
            _ = try PhotoCaptureCropper.crop(truncated, to: .square)
        }
    }

    /// A 64 x 48 HEIC with disparity data at half its size, as a Portrait photo has. The disparity is of 32 bits: the
    /// simulators do not encode the 16-bit one.
    private func makePhotoWithDepth() throws -> Data {
        let image = try FlowTestSupport.makeImage(width: 64, height: 48)
        let data = try #require(CFDataCreateMutable(nil, 0))
        let type = UTType.heic.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithData(data, type, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        let description: [CFString: Any] = [
            "Width" as CFString: 32,
            "Height" as CFString: 24,
            "BytesPerRow" as CFString: 128,
            "PixelFormat" as CFString: kCVPixelFormatType_DisparityFloat32
        ]
        let info: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: Data(count: 128 * 24),
            kCGImageAuxiliaryDataInfoDataDescription: description
        ]
        CGImageDestinationAddAuxiliaryDataInfo(destination, kCGImageAuxiliaryDataTypeDisparity, info as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test("A photo with depth data is reported as uncroppable, since its calibration is of the full frame")
    func depthIsUncroppable() throws {
        let photo = try makePhotoWithDepth()
        let name = kCGImageAuxiliaryDataTypeDisparity as String
        let outcome = try PhotoCaptureCropper.crop(photo, to: .square)
        #expect(outcome == .uncroppable("\(name) carries calibration of the full frame"))
        #expect(try PhotoCaptureCropper.crop(photo, to: .fourByThree) == .unchanged)
    }

    @Test("A capture with depth data reaches the app whole, with the region the viewfinder framed")
    func depthPhotoIsHandedOverWhole() async throws {
        let photo = try makePhotoWithDepth()
        let captured = CapturedPhoto(imageData: photo, encoding: .heif, livePhotoMovieURL: nil)
        let store = CaptureTestSupport.makeFileStore()
        let pipeline = PhotoCapturePipeline(aspectRatio: .square, output: CameraFlowOutput(), store: store)
        let capture = try await pipeline.process(captured)
        #expect(try Data(contentsOf: capture.fileURL) == photo)
        #expect(try capture.uprightPixelSize() == CGSize(width: 64, height: 48))
        let framed = try #require(capture.framedRegion)
        expectClose(framed.minX, 0.125, tolerance: 0.001)
        expectClose(framed.width, 0.75, tolerance: 0.001)
        #expect(framed.minY == 0)
        #expect(framed.height == 1)
        try CaptureTestSupport.discardFiles(of: capture)
    }
}

extension DamagedPhotoTests {
    // MARK: - Location

    private static var position: [CFString: Any] {
        [
            kCGImagePropertyGPSLatitude: 50.45,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 30.52,
            kCGImagePropertyGPSLongitudeRef: "E"
        ]
    }

    @Test("A position without a date and a time is written as it is")
    func positionWithoutTime() throws {
        let outcome = PhotoLocationWriter.addingGPS(Self.position, to: try DevicePhotoFixture.makeCameraFile())
        guard case let .located(data) = outcome else {
            Issue.record("The photo got no location: \(outcome)")
            return
        }
        let properties = try DevicePhotoFixture.properties(of: data)
        let gps = try #require(properties[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        #expect(gps[kCGImagePropertyGPSLatitude] as? Double == 50.45)
        #expect(gps[kCGImagePropertyGPSDateStamp] == nil)
        #expect(gps[kCGImagePropertyGPSTimeStamp] == nil)
    }

    @Test(
        "A date stamp without a time stamp, or the other way round, is refused: the two are one value in the file",
        arguments: [
            (kCGImagePropertyGPSDateStamp as String, "2026:11:11"),
            (kCGImagePropertyGPSTimeStamp as String, "10:15:30")
        ]
    )
    func halfTimestamp(key: String, value: String) throws {
        let photo = try DevicePhotoFixture.makeCameraFile()
        let failure = "The GPS dictionary has a date stamp or a time stamp without the other"
        var gps = Self.position
        gps[key as CFString] = value
        #expect(PhotoLocationWriter.addingGPS(gps, to: photo) == .unlocatable(LoggedReason(failure)))
    }

    @Test("A photo of a type ImageIO reads and does not write keeps its bytes and gets no location")
    func unwritableType() throws {
        let webP = try #require(Data(base64Encoded: "UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA=="))
        #expect(try PhotoFilePreview.contentType(of: webP) == .webP)
        let outcome = PhotoLocationWriter.addingGPS(Self.position, to: webP)
        #expect(outcome == .unlocatable(LoggedReason("ImageIO cannot write org.webmproject.webp")))
    }
}
