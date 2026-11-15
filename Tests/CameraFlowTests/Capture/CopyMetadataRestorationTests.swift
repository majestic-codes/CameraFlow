//
//  CopyMetadataRestorationTests.swift
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

/// The tags ImageIO leaves out of a copy, found and written back without encoding the copy again.
@Suite("Tags a copy lost, written back", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CopyMetadataRestorationTests {
    private let directory = CaptureTestSupport.makeFileStore().directory

    private static var exif: String {
        kCGImagePropertyExifDictionary as String
    }

    private static var tiff: String {
        kCGImagePropertyTIFFDictionary as String
    }

    /// The EXIF of the original: a colour space, two rational values and an aperture.
    private static var originalExif: [CFString: Any] {
        [
            kCGImagePropertyExifColorSpace: 65535,
            kCGImagePropertyExifFNumber: 2.2,
            kCGImagePropertyExifExposureTime: 1.0 / 120,
            kCGImagePropertyExifLensModel: "CameraFlow restoration lens"
        ]
    }

    /// Writes a small Display P3 picture as `type` with the properties.
    private func write(_ name: String, type: UTType, properties: [CFString: Any]) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let context = try #require(
            CGContext(
                data: nil,
                width: 16,
                height: 12,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        )
        context.setFillColor(red: 0.3, green: 0.6, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 12))
        let image = try #require(context.makeImage())
        let url = directory.appendingPathComponent(name)
        let typeIdentifier = type.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, typeIdentifier, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        return url
    }

    private static func source(of url: URL) throws -> CGImageSource {
        try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    }

    @Test("A tag of the photo the copy lacks is lost, unless the copy writes it for its own pixels")
    func lostTags() {
        let original: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifColorSpace: 65535,
                kCGImagePropertyExifFNumber: 1.78,
                kCGImagePropertyExifPixelXDimension: 4032
            ] as [CFString: Any],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFOrientation: 6,
                kCGImagePropertyTIFFTileWidth: 512,
                kCGImagePropertyTIFFTileLength: 512,
                kCGImagePropertyTIFFModel: "iPhone 17 Pro"
            ] as [CFString: Any]
        ]
        let copy: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifFNumber: 1.78] as [CFString: Any]
        ]
        let lost = CopyMetadataRestoration.lostTags(original: original, copy: copy)
        let expected = [
            CopyMetadataRestoration.LostTag(dictionary: Self.exif, key: kCGImagePropertyExifColorSpace as String),
            CopyMetadataRestoration.LostTag(dictionary: Self.tiff, key: kCGImagePropertyTIFFModel as String)
        ]
        #expect(lost == expected)
        #expect(CopyMetadataRestoration.lostTags(original: [:], copy: copy).isEmpty)
    }

    @Test("A copy gets back the tags it lost as the metadata it was encoded with has them, rational values too")
    func restored() throws {
        let originalProperties = [kCGImagePropertyExifDictionary: Self.originalExif]
        let original = try write("original.heic", type: .heic, properties: originalProperties)
        let source = try Self.source(of: original)
        let metadata = try #require(CGImageSourceCopyMetadataAtIndex(source, 0, nil))
        let copy = try write("copy.jpg", type: .jpeg, properties: [:])
        let properties = try ImageFile.properties(of: original)
        let restoredURL = try CopyMetadataRestoration.restoringLostTags(
            of: copy,
            encodedWith: metadata,
            originalProperties: properties,
            in: directory
        )
        #expect(restoredURL != copy)
        #expect(restoredURL.pathExtension == "jpg")
        let restored = try ImageFile.properties(of: restoredURL)
        let exif = try #require(restored[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifColorSpace] as? Int == 65535)
        #expect(exif[kCGImagePropertyExifFNumber] as? Double == 2.2)
        let exposure = try #require(exif[kCGImagePropertyExifExposureTime] as? Double)
        expectClose(exposure, 1.0 / 120, tolerance: 1e-9, "The exposure time")
        #expect(exif[kCGImagePropertyExifLensModel] as? String == "CameraFlow restoration lens")
    }

    @Test("A copy that lost no tag is left as it is")
    func nothingLost() throws {
        let properties = [kCGImagePropertyExifDictionary: Self.originalExif]
        let original = try write("original.heic", type: .heic, properties: properties)
        let source = try Self.source(of: original)
        let metadata = try #require(CGImageSourceCopyMetadataAtIndex(source, 0, nil))
        let writtenProperties = try ImageFile.properties(of: original)
        let restoredURL = try CopyMetadataRestoration.restoringLostTags(
            of: original,
            encodedWith: metadata,
            originalProperties: writtenProperties,
            in: directory
        )
        #expect(restoredURL == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["original.heic"])
    }
}
