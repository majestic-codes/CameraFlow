//
//  PhotoFileCopyTests.swift
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

/// A photo encoded again in a type and a size, with everything else its file holds.
@Suite("A photo copied in another format or size, with everything it holds", .timeLimit(.minutes(1)))
struct PhotoFileCopyTests {
    private static let copies: [(UTType, Int?)] = [(.heic, 128), (.heic, nil), (.jpeg, 128), (.jpeg, nil)]

    private func copy(_ data: Data, as type: UTType, maximumLongSide: Int?) throws -> Data {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try PhotoFileCopy(type: type, compressionQuality: 0.8, maximumLongSide: maximumLongSide).data(of: source)
    }

    private func auxiliarySize(of data: Data, type: CFString, index: Int = 0) throws -> CGSize {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let info = try #require(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, index, type) as? [CFString: Any])
        let description = try #require(info[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString: Any])
        let width = try #require(description["Width" as CFString] as? Int)
        let height = try #require(description["Height" as CFString] as? Int)
        #expect(info[kCGImageAuxiliaryDataInfoMetadata] != nil, "\(type) keeps its own metadata")
        return CGSize(width: width, height: height)
    }

    @Test(
        "A copy keeps every property, every XMP tag and the colour profile of the photo",
        .needsDeviceImageIO(.jpegMetadataCopy),
        arguments: copies
    )
    func metadataKept(type: UTType, maximumLongSide: Int?) throws {
        let photo = try FullPhotoFixture.make()
        let copied = try copy(photo, as: type, maximumLongSide: maximumLongSide)
        try MetadataExpectations.expectKept(from: photo, in: copied)
        for (path, value) in FullPhotoFixture.xmpTags {
            #expect(try MetadataExpectations.xmpValue(at: path, of: copied) == value, "\(path)")
        }
        let properties = try DevicePhotoFixture.properties(of: copied)
        #expect(properties[kCGImagePropertyOrientation] as? Int == FullPhotoFixture.orientation)
    }

    @Test("A copy keeps the gain map scaled with the pixels and the matte at its own size", arguments: copies)
    func auxiliaryImagesKept(type: UTType, maximumLongSide: Int?) throws {
        let photo = try FullPhotoFixture.make()
        let copied = try copy(photo, as: type, maximumLongSide: maximumLongSide)
        let properties = try DevicePhotoFixture.properties(of: copied)
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        let gainMap = try auxiliarySize(of: copied, type: kCGImageAuxiliaryDataTypeHDRGainMap)
        #expect(gainMap == CGSize(width: width / 2, height: height / 2))
        let matte = try auxiliarySize(of: copied, type: kCGImageAuxiliaryDataTypePortraitEffectsMatte)
        #expect(matte == CGSize(width: FullPhotoFixture.width / 4, height: FullPhotoFixture.height / 4))
    }

    @Test(
        "The EXIF of a copy has the copy's size and subject area, also where ImageIO rounds the size its own way",
        arguments: [(UTType.heic, 128), (.heic, 100), (.jpeg, 100), (.heic, 77), (.jpeg, 77)]
    )
    func pixelDescription(type: UTType, maximumLongSide: Int) throws {
        let photo = try FullPhotoFixture.make()
        let copied = try copy(photo, as: type, maximumLongSide: maximumLongSide)
        let properties = try DevicePhotoFixture.properties(of: copied)
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(width == maximumLongSide)
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifPixelXDimension] as? Int == width)
        #expect(exif[kCGImagePropertyExifPixelYDimension] as? Int == height)
        let scale = Double(width) / Double(FullPhotoFixture.width)
        let subjectArea = FullPhotoFixture.subjectArea.map { Int((Double($0) * scale).rounded()) }
        #expect(exif[kCGImagePropertyExifSubjectArea] as? [Int] == subjectArea)
    }

    @Test("A PNG and a TIFF are scaled in their own type, their EXIF giving their size", arguments: [UTType.png, .tiff])
    func losslessTypes(type: UTType) throws {
        let data = try #require(CFDataCreateMutable(nil, 0))
        let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        let width = FullPhotoFixture.width
        let image = try FlowTestSupport.makeImage(width: width, height: FullPhotoFixture.height)
        let exif = [kCGImagePropertyExifPixelXDimension: width] as [CFString: Any]
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyExifDictionary: exif] as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        let copied = try copy(data as Data, as: type, maximumLongSide: 100)
        let properties = try DevicePhotoFixture.properties(of: copied)
        let copyExif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        let height = properties[kCGImagePropertyPixelHeight] as? Int
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 100)
        #expect(copyExif[kCGImagePropertyExifPixelXDimension] as? Int == 100)
        #expect(copyExif[kCGImagePropertyExifPixelYDimension] as? Int == height)
    }

    @Test("A copy of the photo's size keeps its subject area", arguments: [UTType.heic, .jpeg])
    func subjectAreaKept(type: UTType) throws {
        let photo = try FullPhotoFixture.make()
        let copied = try copy(photo, as: type, maximumLongSide: nil)
        let properties = try DevicePhotoFixture.properties(of: copied)
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifSubjectArea] as? [Int] == FullPhotoFixture.subjectArea)
        #expect(exif[kCGImagePropertyExifPixelXDimension] as? Int == FullPhotoFixture.width)
    }

    @Test("A copy carries a thumbnail of its own pixels", arguments: copies)
    func thumbnail(type: UTType, maximumLongSide: Int?) throws {
        let photo = try FullPhotoFixture.make()
        let copied = try copy(photo, as: type, maximumLongSide: maximumLongSide)
        let embedded = try EmbeddedThumbnail.image(in: copied)
        let thumbnail = try #require(embedded, "The copy embeds no thumbnail")
        let longSide = maximumLongSide ?? FullPhotoFixture.width
        #expect(max(thumbnail.width, thumbnail.height) <= longSide)
    }

    @Test(
        "A 10-bit HEIC stays 10-bit, scaled or not",
        .needsDeviceImageIO(.tenBitHEICReencoding),
        arguments: [128, nil]
    )
    func tenBitKept(maximumLongSide: Int?) throws {
        let photo = try DevicePhotoFixture.make(bitsPerComponent: 16)
        let copied = try copy(photo, as: .heic, maximumLongSide: maximumLongSide)
        #expect(try DevicePhotoFixture.properties(of: copied)[kCGImagePropertyDepth] as? Int == 10)
    }

    // MARK: - Stereo pairs

    /// The stereo pair of a copy: the index of each eye and the lens each image says it was taken with.
    private struct StereoPair {
        let left: Int
        let right: Int
        let lenses: [String]

        init(of data: Data) throws {
            let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            let container = try #require(CGImageSourceCopyProperties(source, nil) as? [CFString: Any])
            let groups = try #require(container[kCGImagePropertyGroups] as? [[CFString: Any]])
            let pair = try #require(groups.first)
            #expect(pair[kCGImagePropertyGroupType] as? String == kCGImagePropertyGroupTypeStereoPair as String)
            let adjustment = pair[kCGImagePropertyGroupImageDisparityAdjustment] as? Int
            #expect(adjustment == FullPhotoFixture.disparityAdjustment)
            left = try #require(pair[kCGImagePropertyGroupImageIndexLeft] as? Int)
            right = try #require(pair[kCGImagePropertyGroupImageIndexRight] as? Int)
            lenses = try (0..<CGImageSourceGetCount(source)).map { index in
                let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
                let exif = try #require(properties?[kCGImagePropertyExifDictionary] as? [CFString: Any])
                return try #require(exif[kCGImagePropertyExifLensModel] as? String)
            }
        }
    }

    @Test("A HEIC copy of a spatial photo keeps both eyes in their pair, each with its own EXIF", arguments: [128, nil])
    func stereoPairKept(maximumLongSide: Int?) throws {
        let photo = try FullPhotoFixture.makeStereoPair()
        let copied = try copy(photo, as: .heic, maximumLongSide: maximumLongSide)
        let source = try #require(CGImageSourceCreateWithData(copied as CFData, nil))
        try #require(CGImageSourceGetCount(source) == 2)
        let pair = try StereoPair(of: copied)
        #expect(pair.lenses[pair.left] == FullPhotoFixture.lensModels.left)
        #expect(pair.lenses[pair.right] == FullPhotoFixture.lensModels.right)
        let width = maximumLongSide ?? FullPhotoFixture.width
        for index in 0..<2 {
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any])
            #expect(properties[kCGImagePropertyPixelWidth] as? Int == width)
            #expect(properties[kCGImagePropertyHEIFDictionary] != nil, "The eye keeps its camera position")
            let gainMap = try auxiliarySize(of: copied, type: kCGImageAuxiliaryDataTypeHDRGainMap, index: index)
            #expect(Int(gainMap.width) == width / 2)
        }
        #expect(try MetadataExpectations.xmpValue(at: "xmp:Label", of: copied) == FullPhotoFixture.xmpTags["xmp:Label"])
    }

    @Test("A JPEG copy of a spatial photo is its left eye, a JPEG holding one image")
    func stereoPairInJPEG() throws {
        let pair = try FullPhotoFixture.makeStereoPair()
        let copied = try copy(pair, as: .jpeg, maximumLongSide: 128)
        let source = try #require(CGImageSourceCreateWithData(copied as CFData, nil))
        #expect(CGImageSourceGetCount(source) == 1)
        let properties = try DevicePhotoFixture.properties(of: copied)
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifLensModel] as? String == FullPhotoFixture.lensModels.left)
    }

    // MARK: - Subject area

    @Test(
        "A subject area follows a crop, its centre and size kept inside the cropped frame",
        arguments: [
            ([2014, 1512, 2218, 1331], CGRect(x: 504, y: 0, width: 3024, height: 3024), [1510, 1512, 2218, 1331]),
            ([2014, 1512, 2218, 1331], CGRect(x: 0, y: 378, width: 4032, height: 2268), [2014, 1134, 2218, 1331]),
            ([100, 3000, 5000, 400], CGRect(x: 504, y: 0, width: 3024, height: 3024), [0, 3000, 3024, 400]),
            ([2014, 1512, 4000], CGRect(x: 504, y: 0, width: 3024, height: 3024), [1510, 1512, 3024]),
            ([2014, 10], CGRect(x: 0, y: 378, width: 4032, height: 2268), [2014, 0])
        ]
    )
    func subjectAreaCropped(values: [Int], rectangle: CGRect, expected: [Int]) throws {
        #expect(try PhotoSubjectArea.cropped(values, to: rectangle) == expected)
    }

    @Test("A subject area of another number of values cannot follow a crop", arguments: [[1], [1, 2, 3, 4, 5]])
    func malformedSubjectArea(values: [Int]) {
        #expect(throws: PhotoSubjectArea.Malformed(valueCount: values.count)) {
            try PhotoSubjectArea.cropped(values, to: CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }
}
