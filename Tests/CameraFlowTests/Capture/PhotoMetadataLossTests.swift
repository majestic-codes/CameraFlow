//
//  PhotoMetadataLossTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import CameraFlow

/// What a photo written again lost against its source, which decides whether a photo gets its location.
@Suite("What a photo written again lost")
struct PhotoMetadataLossTests {

    private func source(of data: Data) throws -> CGImageSource {
        try #require(CGImageSourceCreateWithData(data as CFData, nil))
    }

    private func photo(of data: Data) throws -> ImageSourcePhoto {
        try ImageSourcePhoto(data: data)
    }

    /// The photo written again without encoding its image, with its complete metadata changed by `change`.
    private func lossless(_ data: Data, change: (CGMutableImageMetadata) throws -> Void = { _ in }) throws -> Data {
        let photoSource = try source(of: data)
        let metadata = try #require(CGImageSourceCopyMetadataAtIndex(photoSource, 0, nil))
        let changed = try #require(CGImageMetadataCreateMutableCopy(metadata))
        try change(changed)
        let output = try #require(CFDataCreateMutable(nil, 0))
        let destination = try #require(CGImageDestinationCreateWithData(output, "public.heic" as CFString, 1, nil))
        let options = [kCGImageDestinationMetadata: changed, kCGImageDestinationMergeMetadata: false] as CFDictionary
        try #require(CGImageDestinationCopyImageSource(destination, photoSource, options, nil))
        return output as Data
    }

    /// The photo written again without encoding its image, with the aperture of its metadata set. XMP holds the
    /// rational as a fraction.
    private func withAperture(_ fraction: String, of data: Data) throws -> Data {
        try lossless(data) { metadata in
            let exif = kCGImagePropertyExifDictionary
            let key = kCGImagePropertyExifFNumber
            try #require(CGImageMetadataSetValueMatchingImageProperty(metadata, exif, key, fraction as CFString))
        }
    }

    /// The photo copied by ImageIO with the auxiliary images given in place of its own.
    private func copy(of data: Data, auxiliaryImages: [(CFString, CFDictionary)]) throws -> Data {
        let output = try #require(CFDataCreateMutable(nil, 0))
        let destination = try #require(CGImageDestinationCreateWithData(output, "public.heic" as CFString, 1, nil))
        CGImageDestinationAddImageFromSource(destination, try source(of: data), 0, nil)
        for (type, info) in auxiliaryImages {
            CGImageDestinationAddAuxiliaryDataInfo(destination, type, info)
        }
        try #require(CGImageDestinationFinalize(destination))
        return output as Data
    }

    @Test("A photo written again without encoding its image lost nothing")
    func nothingLost() throws {
        let original = try DevicePhotoFixture.makeCameraFile()
        let written = try lossless(original)
        #expect(PhotoMetadataLoss.loss(from: try photo(of: original), to: written) == nil)
    }

    @Test("A photo written without its GPS dictionary lost it")
    func lostDictionary() throws {
        let original = try DevicePhotoFixture.make()
        let written = try lossless(original) { metadata in
            let tags = try #require(CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag])
            for tag in tags {
                let name = try #require(CGImageMetadataTagCopyName(tag)) as String
                guard name.hasPrefix("GPS"), let prefix = CGImageMetadataTagCopyPrefix(tag) else { continue }
                try #require(CGImageMetadataRemoveTagWithPath(metadata, nil, "\(prefix):\(name)" as CFString))
            }
        }
        let loss = PhotoMetadataLoss.loss(from: try photo(of: original), to: written)
        #expect(loss == LoggedReason("The written photo lost {GPS}"))
    }

    @Test("A photo with another aperture changed it, and says from what to what in the details a log keeps private")
    func changedValue() throws {
        let original = try DevicePhotoFixture.makeCameraFile()
        let written = try withAperture("28/10", of: original)
        let loss = PhotoMetadataLoss.loss(from: try photo(of: original), to: written)
        #expect(loss == LoggedReason("The written photo changed {Exif}.FNumber", details: "1.78 to 2.8"))
        #expect(loss?.description == "The written photo changed {Exif}.FNumber (1.78 to 2.8)")
    }

    @Test("A property the caller writes itself is not compared")
    func ignoredKey() throws {
        let original = try DevicePhotoFixture.makeCameraFile()
        let written = try withAperture("28/10", of: original)
        let originalPhoto = try photo(of: original)
        let loss = PhotoMetadataLoss.loss(from: originalPhoto, to: written, ignoring: ["{Exif}"])
        #expect(loss == nil)
    }

    @Test("A gain map with other bytes is a changed auxiliary image")
    func changedAuxiliaryImage() throws {
        let original = try DevicePhotoFixture.makeCameraFile()
        let originalSource = try source(of: original)
        let type = kCGImageAuxiliaryDataTypeHDRGainMap
        var info = try #require(CGImageSourceCopyAuxiliaryDataInfoAtIndex(originalSource, 0, type) as? [CFString: Any])
        let pixels = try #require(info[kCGImageAuxiliaryDataInfoData] as? Data)
        info[kCGImageAuxiliaryDataInfoData] = Data(pixels.map { $0 ^ 0xFF })
        let written = try copy(of: original, auxiliaryImages: [(type, info as CFDictionary)])
        let loss = PhotoMetadataLoss.loss(from: try ImageSourcePhoto(source: originalSource, index: 0), to: written)
        #expect(loss == LoggedReason("The written photo changed the auxiliary image \(type)"))
    }

    @Test("A photo of two images written as one has another image count")
    func imageCount() throws {
        let pair = try FullPhotoFixture.makeStereoPair()
        let single = try FullPhotoFixture.make()
        let loss = PhotoMetadataLoss.loss(from: try photo(of: pair), to: single)
        #expect(loss == LoggedReason("The written photo has another image count"))
        #expect(PhotoMetadataLoss.loss(from: try photo(of: pair), to: Data()) == loss)
    }

    @Test(
        "A number written again within the tolerance of a rational is kept, and one beyond it is changed",
        arguments: [(1.78 * (1 + 5e-9), true), (1.78 * (1 + 5e-7), false), (1.78, true)]
    )
    func numberTolerance(written: Double, isKept: Bool) {
        let difference = PhotoMetadataLoss.difference(between: 1.78, and: written, path: "{Exif}.FNumber")
        #expect((difference == nil) == isKept)
    }

    @Test("A dictionary may gain keys and never lose one, and a list keeps its length and its values")
    func structures() {
        let original: [String: Any] = ["a": 1, "b": [1.0, 2.0]]
        let gained: [String: Any] = ["a": 1, "b": [1.0, 2.0], "c": "new"]
        #expect(PhotoMetadataLoss.difference(between: original, and: gained, path: "{Exif}") == nil)
        let lost: [String: Any] = ["b": [1.0, 2.0]]
        let removed = PhotoMetadataLoss.difference(between: original, and: lost, path: "{Exif}")
        #expect(removed == PhotoMetadataLoss.Difference(path: "{Exif}.a (removed)"))
        let shorter: [String: Any] = ["a": 1, "b": [1.0]]
        let shortened = PhotoMetadataLoss.difference(between: original, and: shorter, path: "{Exif}")
        #expect(shortened == PhotoMetadataLoss.Difference(path: "{Exif}.b"))
        let changed: [String: Any] = ["a": 1, "b": [1.0, 3.0]]
        let difference = PhotoMetadataLoss.difference(between: original, and: changed, path: "{Exif}")
        #expect(difference == PhotoMetadataLoss.Difference(path: "{Exif}.b[1]", values: "2.0 to 3.0"))
        let otherKind = PhotoMetadataLoss.difference(between: "text", and: 1, path: "{TIFF}.Make")
        #expect(otherKind == PhotoMetadataLoss.Difference(path: "{TIFF}.Make"))
    }

    /// A value of a property and the value written again, and whether the written one keeps it.
    struct ScalarCase: Sendable, CustomTestStringConvertible {
        let name: String
        let original: any Sendable
        let written: any Sendable
        let isKept: Bool

        var testDescription: String {
            name
        }
    }

    static let scalarCases = [
        ScalarCase(name: "the same text", original: "Apple", written: "Apple", isKept: true),
        ScalarCase(name: "another text", original: "Apple", written: "apple", isKept: false),
        ScalarCase(name: "the same bytes", original: Data([1, 2, 3]), written: Data([1, 2, 3]), isKept: true),
        ScalarCase(name: "other bytes", original: Data([1, 2, 3]), written: Data([1, 2]), isKept: false),
        ScalarCase(name: "the same flag", original: true, written: true, isKept: true),
        ScalarCase(name: "a whole number written as a fraction", original: 24, written: 24.0, isKept: true)
    ]

    @Test("A value written again is kept when it is equal, whatever kind of value it is", arguments: scalarCases)
    func scalars(scalarCase: ScalarCase) {
        let difference = PhotoMetadataLoss.difference(
            between: scalarCase.original,
            and: scalarCase.written,
            path: "{TIFF}.Make"
        )
        #expect((difference == nil) == scalarCase.isKept)
    }
}
