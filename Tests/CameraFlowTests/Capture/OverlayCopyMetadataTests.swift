//
//  OverlayCopyMetadataTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// The copy with a drawing and the copy with the second camera's circle keep the metadata of the photo as a copy
/// without an overlay does, for their upright pixels: every key and XMP tag with its value, a thumbnail of their own
/// pixels, and the subject area turned upright with the pixels and scaled with them.
@Suite("Overlay copy: metadata, thumbnail and subject area", .temporaryDirectory, .timeLimit(.minutes(1)))
struct OverlayCopyMetadataTests {
    /// What a copy draws over its photo.
    enum Overlay: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case drawing
        case circle

        var testDescription: String {
            rawValue
        }
    }

    /// The colour of the mark around the centre of a subject area.
    private static let markColor = PixelGrid.Pixel(red: 230, green: 30, blue: 40)

    private let directory = CaptureTestSupport.makeFileStore().directory

    private var copies: URL {
        directory.appendingPathComponent("Copies", isDirectory: true)
    }

    /// Writes the photo into the test's folder with the extension of its type.
    private func write(_ photo: Data, type: UTType) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("photo").appendingPathExtension(for: type)
        try photo.write(to: url)
        return url
    }

    /// The copy of the photo at `url` with the overlay in the output: a small square in the bottom left corner, or
    /// the circle in the top right corner of a portrait viewfinder.
    private func copy(
        of url: URL,
        with overlay: Overlay,
        output: CameraFlowOutput = CameraFlowOutput()
    ) async throws -> Data {
        let copyURL: URL
        switch overlay {
        case .drawing:
            copyURL = try await OverlayPhotoWriter.writeCopy(
                of: url,
                into: copies,
                label: "markup",
                output: output
            ) { bitmap, _ in
                bitmap.setFillColor(CGColor(srgbRed: 0.1, green: 0.9, blue: 0.2, alpha: 1))
                bitmap.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }
        case .circle:
            let frame = try DualCameraFixture.makeCircleFrame(
                uprightSize: (60, 80),
                orientation: 6,
                viewfinderQuarterTurns: 0
            )
            let composition = DualCameraPhotoWriter.Composition(
                frame: frame,
                circle: DualCameraFixture.circle(region: CGRect(x: 0.6, y: 0.05, width: 0.3, height: 0.225)),
                framedRegion: nil
            )
            copyURL = try await DualCameraPhotoWriter.writeCopy(
                of: url,
                composition: composition,
                into: copies,
                output: output
            )
        }
        return try Data(contentsOf: copyURL)
    }

    // MARK: - Metadata

    /// A photo of a type and the format its copy is written in.
    struct MetadataCase: Sendable, CustomTestStringConvertible {
        let name: String
        let type: UTType
        let format: CameraFlowOutputFormat

        var testDescription: String {
            name
        }
    }

    static let metadataCases = [
        MetadataCase(name: "HEIC copied as it is", type: .heic, format: .original),
        MetadataCase(name: "JPEG copied as it is", type: .jpeg, format: .original),
        MetadataCase(name: "HEIC copied as a JPEG", type: .heic, format: .jpeg(quality: 0.8)),
        MetadataCase(name: "JPEG copied as a HEIC", type: .jpeg, format: .heic(quality: 0.8))
    ]

    @Test(
        "A copy keeps every property, every XMP tag and the colour profile of the photo, with the orientation 1",
        .needsDeviceImageIO(.jpegMetadataCopy),
        arguments: Overlay.allCases,
        metadataCases
    )
    func metadataKept(overlay: Overlay, metadataCase: MetadataCase) async throws {
        let photo = try FullPhotoFixture.make(type: metadataCase.type)
        var output = CameraFlowOutput()
        output.format = metadataCase.format
        let url = try write(photo, type: metadataCase.type)
        let copied = try await copy(of: url, with: overlay, output: output)
        try MetadataExpectations.expectKept(from: photo, in: copied, changing: MetadataExpectations.uprightPixelKeys)
        for (path, value) in FullPhotoFixture.xmpTags {
            #expect(try MetadataExpectations.xmpValue(at: path, of: copied) == value, "\(path)")
        }
        let properties = try DevicePhotoFixture.properties(of: copied)
        #expect(properties[kCGImagePropertyOrientation] as? Int == 1)
    }

    @Test(
        "A copy of the camera's file keeps every EXIF, TIFF and maker key with its value",
        arguments: Overlay.allCases
    )
    func cameraFileKept(overlay: Overlay) async throws {
        let photo = try DevicePhotoFixture.makeCameraFile()
        let url = try write(photo, type: .heic)
        let copied = try await copy(of: url, with: overlay)
        try MetadataExpectations.expectKept(from: photo, in: copied, changing: MetadataExpectations.uprightPixelKeys)
    }

    // MARK: - Thumbnail

    @Test("A copy carries a thumbnail of its own upright pixels", arguments: Overlay.allCases, [UTType.heic, .jpeg])
    func thumbnail(overlay: Overlay, type: UTType) async throws {
        let photo = try FullPhotoFixture.make(type: type)
        let url = try write(photo, type: type)
        let copied = try await copy(of: url, with: overlay)
        let embedded = try EmbeddedThumbnail.image(in: copied)
        let thumbnail = try #require(embedded, "The copy embeds no thumbnail")
        let properties = try DevicePhotoFixture.properties(of: copied)
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(max(thumbnail.width, thumbnail.height) <= max(width, height))
        // The thumbnail has the proportions of the upright copy, within a pixel.
        #expect(abs(thumbnail.width * height - thumbnail.height * width) <= max(width, height))
        #expect(thumbnail.height > thumbnail.width)
    }

    @Test("A copy without the metadata has no thumbnail either", arguments: Overlay.allCases, [UTType.heic, .jpeg])
    func strippedThumbnail(overlay: Overlay, type: UTType) async throws {
        let photo = try FullPhotoFixture.make(type: type)
        let url = try write(photo, type: type)
        var output = CameraFlowOutput()
        output.metadata = .stripped
        let copied = try await copy(of: url, with: overlay, output: output)
        #expect(try EmbeddedThumbnail.image(in: copied) == nil)
    }

    // MARK: - Subject area

    /// Writes a HEIC of 64 x 48 stored pixels with the orientation and the subject area in its EXIF: grey, and the
    /// mark colour in the 8 x 8 square around (20, 12), where the subject area of the fixture is centred.
    private func subjectAreaPhoto(orientation: Int, subjectArea: [Int] = [20, 12, 8, 4]) throws -> URL {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: nil,
                width: 64,
                height: 48,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        )
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        let mark = Self.markColor
        let components = [mark.red, mark.green, mark.blue].map { CGFloat($0) / 255 }
        context.setFillColor(red: components[0], green: components[1], blue: components[2], alpha: 1)
        // The bitmap counts rows from the bottom: rows 8 to 15 from the top.
        context.fill(CGRect(x: 16, y: 32, width: 8, height: 8))
        let image = try #require(context.makeImage())
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("subject-\(orientation)").appendingPathExtension(for: .heic)
        let typeIdentifier = UTType.heic.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, typeIdentifier, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 1,
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifSubjectArea: subjectArea,
                kCGImagePropertyExifPixelXDimension: 64,
                kCGImagePropertyExifPixelYDimension: 48
            ] as [CFString: Any]
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        return url
    }

    private static func pixels(of data: Data) throws -> PixelGrid {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return try PixelGrid(image)
    }

    /// The subject area of the photo's EXIF, empty for a photo without one.
    private static func subjectArea(of data: Data) throws -> [Int] {
        let properties = try DevicePhotoFixture.properties(of: data)
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        guard let value = exif[kCGImagePropertyExifSubjectArea] else { return [] }
        return try #require(value as? [Int])
    }

    /// The subject area of the fixture in its upright pixels, for each orientation: the centre moves with the pixel
    /// it is on, and the rectangle turns with the photo.
    static let uprightSubjectAreas: [(orientation: Int, subjectArea: [Int])] = [
        (1, [20, 12, 8, 4]),
        (2, [43, 12, 8, 4]),
        (3, [43, 35, 8, 4]),
        (4, [20, 35, 8, 4]),
        (5, [12, 20, 4, 8]),
        (6, [35, 20, 4, 8]),
        (7, [35, 43, 4, 8]),
        (8, [12, 43, 4, 8])
    ]

    @Test("The subject area of a copy is the photo's, turned upright with its pixels", arguments: uprightSubjectAreas)
    func uprightSubjectArea(orientation: Int, subjectArea: [Int]) async throws {
        let url = try subjectAreaPhoto(orientation: orientation)
        let original = try Data(contentsOf: url)
        try #require(try Self.subjectArea(of: original) == [20, 12, 8, 4])
        let copied = try await copy(of: url, with: .drawing)
        #expect(try Self.subjectArea(of: copied) == subjectArea)
        let centre = try Self.pixels(of: copied)[subjectArea[0], subjectArea[1]]
        #expect(centre.isClose(to: Self.markColor), "The centre of the subject area shows \(centre)")
    }

    @Test("The subject area of a smaller copy is scaled with it", arguments: Overlay.allCases)
    func scaledSubjectArea(overlay: Overlay) async throws {
        let url = try subjectAreaPhoto(orientation: 6)
        var output = CameraFlowOutput()
        output.size = .longSide(maximum: 32)
        let copied = try await copy(of: url, with: overlay, output: output)
        let properties = try DevicePhotoFixture.properties(of: copied)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 24)
        #expect(try Self.subjectArea(of: copied) == [18, 10, 2, 4])
    }

    @Test("A subject area of a number of values no rule turns leaves the copy, and the rest of the EXIF stays")
    func malformedSubjectArea() async throws {
        let url = try subjectAreaPhoto(orientation: 6, subjectArea: [20, 12, 8, 4, 2])
        let original = try Data(contentsOf: url)
        try #require(try Self.subjectArea(of: original).count == 5)
        let copied = try await copy(of: url, with: .drawing)
        #expect(try Self.subjectArea(of: copied).isEmpty)
        let properties = try DevicePhotoFixture.properties(of: copied)
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifPixelXDimension] as? Int == 48)
        #expect(exif[kCGImagePropertyExifPixelYDimension] as? Int == 64)
    }
}
