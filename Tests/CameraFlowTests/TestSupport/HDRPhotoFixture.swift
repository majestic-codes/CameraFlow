//
//  HDRPhotoFixture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// A small HDR photo with every auxiliary image a copy carries, shaped like the camera's. Its upright picture is the
/// four coloured quarters of `OrientedPhotoFixture`, stored turned and mirrored the way its EXIF orientation says, in
/// Display P3 with 8 or 16 bits a component (16 encode as a 10-bit HEIC). It has EXIF with the colour space 65535,
/// TIFF, GPS, the maker tags of an HDR headroom of 8 and an XMP label.
///
/// The auxiliary images lie in the frame of the stored pixels, as the camera writes them, and show the quarters too:
/// the gain maps, half the photo on each side, and the portrait effects matte, the sky matte and disparity, a quarter
/// of it.
enum HDRPhotoFixture {
    typealias Quarter = OrientedPhotoFixture.Quarter

    enum FixtureError: Error {
        case cannotEncode
    }

    /// The auxiliary images of a fixture.
    enum Kind: Sendable {
        /// Apple's gain map and, where the system has it, the ISO one, the way the camera writes them: ImageIO keeps
        /// one picture for both, and level 0 is no boost in both. The mattes and disparity go with them.
        case cameraHDR
        /// The ISO gain map alone, with a gain range of -1 to 2 stops, which puts no boost at level 85, and the
        /// mattes and disparity.
        case isoGainMapWithDarkening
        /// No auxiliary image: a photo of the standard range.
        case standardRange
    }

    static let uprightWidth = OrientedPhotoFixture.uprightWidth
    static let uprightHeight = OrientedPhotoFixture.uprightHeight
    static let lensModel = "CameraFlow HDR fixture lens"
    static let colorSpaceTag = 65535
    static let latitude = 46.48
    /// The headroom the maker tags 33 and 48 give Apple's gain map.
    static let headroom = 8.0
    /// The no boost level of the ISO gain map that darkens as well: a third of its levels.
    static let darkeningNoBoostLevel: UInt8 = 85
    static let xmpValue = "CameraFlow HDR fixture"
    static var xmpPath: CFString {
        "xmp:Label" as CFString
    }

    static var mattes: [CFString] {
        [kCGImageAuxiliaryDataTypePortraitEffectsMatte, kCGImageAuxiliaryDataTypeSemanticSegmentationSkyMatte]
    }

    /// The gain map types of a fixture of the kind.
    static func gainMapTypes(_ kind: Kind) -> [CFString] {
        switch kind {
        case .cameraHDR:
            return PhotoGainMap.types
        case .isoGainMapWithDarkening:
            guard #available(iOS 18, macOS 15, *) else { return [] }
            return [kCGImageAuxiliaryDataTypeISOGainMap]
        case .standardRange:
            return []
        }
    }

    /// The auxiliary images of one-byte levels: the gain maps and the mattes.
    static func levelTypes(_ kind: Kind = .cameraHDR) -> [CFString] {
        kind == .standardRange ? [] : gainMapTypes(kind) + mattes
    }

    /// Every auxiliary image type of a fixture of the kind.
    static func auxiliaryTypes(_ kind: Kind = .cameraHDR) -> [CFString] {
        kind == .standardRange ? [] : levelTypes(kind) + [kCGImageAuxiliaryDataTypeDisparity]
    }

    /// How many times the photo's side an auxiliary image's side is.
    static func scale(of type: CFString) -> Int {
        PhotoGainMap.types.contains(type) ? 2 : 4
    }

    /// The upright size of an auxiliary image of the fixture.
    static func uprightSize(of type: CFString) -> (width: Int, height: Int) {
        (uprightWidth / scale(of: type), uprightHeight / scale(of: type))
    }

    /// The level of a quarter in an auxiliary image of one-byte levels. The gain maps boost the top left quarter,
    /// where an overlay goes, the most.
    static func level(of quarter: Quarter, in type: CFString) -> UInt8 {
        if PhotoGainMap.types.contains(type) {
            return switch quarter {
            case .topLeft: 255
            case .topRight: 170
            case .bottomLeft: 100
            case .bottomRight: 40
            }
        }
        return switch quarter {
        case .topLeft: 230
        case .topRight: 160
        case .bottomLeft: 90
        case .bottomRight: 20
        }
    }

    static func disparity(of quarter: Quarter) -> Float {
        switch quarter {
        case .topLeft: 0.2
        case .topRight: 0.4
        case .bottomLeft: 0.6
        case .bottomRight: 0.8
        }
    }

    /// Writes a fixture of the kind as `name` with the extension of `type` into `directory`, which it creates.
    static func makeFile(
        orientation: Int,
        type: UTType,
        bitsPerComponent: Int = 8,
        kind: Kind = .cameraHDR,
        in directory: URL,
        name: String = "hdr"
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileExtension = try #require(type.preferredFilenameExtension)
        let url = directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
        let typeIdentifier = type.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, typeIdentifier, 1, nil))
        let image = try storedImage(orientation: orientation, bitsPerComponent: bitsPerComponent)
        let metadata = CGImageMetadataCreateMutable()
        try #require(CGImageMetadataSetValueWithPath(metadata, nil, xmpPath, xmpValue as CFString))
        let properties = properties(orientation: orientation, width: image.width, height: image.height)
        CGImageDestinationAddImageAndMetadata(destination, image, metadata, properties as CFDictionary)
        for auxiliaryType in auxiliaryTypes(kind) {
            let info = try auxiliaryInfo(of: auxiliaryType, orientation: orientation, kind: kind)
            CGImageDestinationAddAuxiliaryDataInfo(destination, auxiliaryType, info as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError.cannotEncode
        }
        guard type == .jpeg, kind == .standardRange else { return url }
        return try keepingColorSpaceTag(of: url)
    }

    /// The JPEG written again without encoding it, with the colour space tag ImageIO's JPEG encoder drops from a
    /// Display P3 picture without auxiliary images.
    private static func keepingColorSpaceTag(of url: URL) throws -> URL {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let index = CGImageSourceGetPrimaryImageIndex(source)
        let sourceMetadata = try #require(CGImageSourceCopyMetadataAtIndex(source, index, nil))
        let metadata = try #require(CGImageMetadataCreateMutableCopy(sourceMetadata))
        let exif = kCGImagePropertyExifDictionary
        let tag = colorSpaceTag as CFNumber
        try #require(CGImageMetadataSetValueMatchingImageProperty(metadata, exif, kCGImagePropertyExifColorSpace, tag))
        let taggedURL = url.deletingLastPathComponent().appendingPathComponent("tagged-\(url.lastPathComponent)")
        let type = UTType.jpeg.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithURL(taggedURL as CFURL, type, 1, nil))
        let options = [kCGImageDestinationMetadata: metadata, kCGImageDestinationMergeMetadata: false] as CFDictionary
        try #require(CGImageDestinationCopyImageSource(destination, source, options, nil))
        try FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: taggedURL, to: url)
        return url
    }

    private static func properties(orientation: Int, width: Int, height: Int) -> [CFString: Any] {
        [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 0.95,
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifColorSpace: colorSpaceTag,
                kCGImagePropertyExifLensModel: lensModel,
                kCGImagePropertyExifFNumber: 1.78,
                kCGImagePropertyExifExposureTime: 1.0 / 120,
                kCGImagePropertyExifISOSpeedRatings: [64],
                kCGImagePropertyExifDateTimeOriginal: "2026:11:14 09:30:12",
                kCGImagePropertyExifSubsecTimeOriginal: "250",
                kCGImagePropertyExifPixelXDimension: width,
                kCGImagePropertyExifPixelYDimension: height
            ] as [CFString: Any],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Apple",
                kCGImagePropertyTIFFModel: "iPhone 17 Pro",
                kCGImagePropertyTIFFSoftware: "27.2"
            ] as [CFString: Any],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: latitude,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 30.73,
                kCGImagePropertyGPSLongitudeRef: "E"
            ] as [CFString: Any],
            kCGImagePropertyMakerAppleDictionary: [
                "8": [0.012, -0.81, -0.59],
                "33": 1.01,
                "43": "5C1D0A6E-2B47-4D8E-9F31-7A2C4E6B8D90",
                "48": 0.0
            ] as [String: Any]
        ]
    }

    /// The pixels the file stores, in Display P3: the upright quarters read through the orientation backwards.
    private static func storedImage(orientation: Int, bitsPerComponent: Int) throws -> CGImage {
        let isTurned = orientation >= 5
        let width = isTurned ? uprightHeight : uprightWidth
        let height = isTurned ? uprightWidth : uprightHeight
        let byteOrder = bitsPerComponent == 16 ? CGBitmapInfo.byteOrder16Little.rawValue : 0
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | byteOrder
            )
        )
        let srgb = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        for row in 0..<height {
            for column in 0..<width {
                let stored = (column: column, row: row)
                let upright = uprightPixel(stored, orientation: orientation, width: width, height: height)
                let color = Quarter.containing(column: upright.column, row: upright.row).color
                let components = [color.red, color.green, color.blue].map { CGFloat($0) / 255 } + [1]
                context.setFillColor(try #require(CGColor(colorSpace: srgb, components: components)))
                // The bitmap counts rows from the bottom.
                context.fill(CGRect(x: column, y: height - 1 - row, width: 1, height: 1))
            }
        }
        return try #require(context.makeImage())
    }

    /// The info of an auxiliary image in the frame of the stored pixels.
    private static func auxiliaryInfo(of type: CFString, orientation: Int, kind: Kind) throws -> [CFString: Any] {
        let upright = uprightSize(of: type)
        let isTurned = orientation >= 5
        let width = isTurned ? upright.height : upright.width
        let height = isTurned ? upright.width : upright.height
        let isDisparity = type == kCGImageAuxiliaryDataTypeDisparity
        let bytesPerPixel = isDisparity ? 4 : 1
        var pixels = Data()
        for row in 0..<height {
            for column in 0..<width {
                let stored = (column: column, row: row)
                let pixel = uprightPixel(stored, orientation: orientation, width: width, height: height)
                let isLeft = pixel.column < upright.width / 2
                let isTop = pixel.row < upright.height / 2
                let quarter: Quarter = isTop ? (isLeft ? .topLeft : .topRight) : (isLeft ? .bottomLeft : .bottomRight)
                if isDisparity {
                    withUnsafeBytes(of: disparity(of: quarter)) { pixels.append(contentsOf: $0) }
                } else {
                    pixels.append(level(of: quarter, in: type))
                }
            }
        }
        let pixelFormat = isDisparity ? kCVPixelFormatType_DisparityFloat32 : kCVPixelFormatType_OneComponent8
        let description: [CFString: Any] = [
            "Width" as CFString: width,
            "Height" as CFString: height,
            "BytesPerRow" as CFString: width * bytesPerPixel,
            "PixelFormat" as CFString: pixelFormat
        ]
        var info: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: pixels,
            kCGImageAuxiliaryDataInfoDataDescription: description
        ]
        if type == kCGImageAuxiliaryDataTypeHDRGainMap {
            info[kCGImageAuxiliaryDataInfoMetadata] = try appleGainMapMetadata()
        }
        if #available(iOS 18, macOS 15, *), type == kCGImageAuxiliaryDataTypeISOGainMap {
            let darkens = kind == .isoGainMapWithDarkening
            let iso = try isoGainMapInfo(minimum: darkens ? -1 : 0, maximum: darkens ? 2 : log2(headroom), gamma: 1)
            info[kCGImageAuxiliaryDataInfoMetadata] = iso[kCGImageAuxiliaryDataInfoMetadata]
            info[kCGImageAuxiliaryDataInfoColorSpace] = iso[kCGImageAuxiliaryDataInfoColorSpace]
        }
        return info
    }

    /// Where a stored pixel lies in the upright picture, for stored pixels of the given size.
    private static func uprightPixel(
        _ stored: (column: Int, row: Int),
        orientation: Int,
        width: Int,
        height: Int
    ) -> (column: Int, row: Int) {
        let (column, row) = stored
        let isTurned = orientation >= 5
        let right = (isTurned ? height : width) - 1
        let bottom = (isTurned ? width : height) - 1
        return switch orientation {
        case 2: (right - column, row)
        case 3: (right - column, bottom - row)
        case 4: (column, bottom - row)
        case 5: (row, column)
        case 6: (right - row, column)
        case 7: (right - row, bottom - column)
        case 8: (row, bottom - column)
        default: (column, row)
        }
    }
}

extension HDRPhotoFixture {

    private static func appleGainMapMetadata() throws -> CGImageMetadata {
        let metadata = CGImageMetadataCreateMutable()
        let namespace = "http://ns.apple.com/HDRGainMap/1.0/" as CFString
        try #require(CGImageMetadataRegisterNamespaceForPrefix(metadata, namespace, "HDRGainMap" as CFString, nil))
        let versionPath = "HDRGainMap:HDRGainMapVersion" as CFString
        try #require(CGImageMetadataSetValueWithPath(metadata, nil, versionPath, 131_072 as CFNumber))
        return metadata
    }

    /// The info of an ISO gain map as ImageIO writes it, its metadata set to the gain range and the gamma given:
    /// read from a small HDR picture ImageIO encodes with an ISO gain map.
    @available(iOS 18, macOS 15, *)
    static func isoGainMapInfo(minimum: Double, maximum: Double, gamma: Double) throws -> [CFString: Any] {
        let photo = try isoGainMapPhoto()
        let source = try #require(CGImageSourceCreateWithData(photo as CFData, nil))
        let type = kCGImageAuxiliaryDataTypeISOGainMap
        var info = try #require(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, type) as? [CFString: Any])
        let value = try #require(info[kCGImageAuxiliaryDataInfoMetadata] as CFTypeRef?)
        try #require(CFGetTypeID(value) == CGImageMetadataGetTypeID())
        let metadata = try #require(CGImageMetadataCreateMutableCopy(unsafeDowncast(value, to: CGImageMetadata.self)))
        let channel = "HDRToneMap:ChannelMetadata[0].HDRToneMap:"
        for (name, number) in [("GainMapMin", minimum), ("GainMapMax", maximum), ("Gamma", gamma)] {
            let text = String(format: "%.6f", number) as CFString
            try #require(CGImageMetadataSetValueWithPath(metadata, nil, (channel + name) as CFString, text))
        }
        info[kCGImageAuxiliaryDataInfoMetadata] = metadata
        return info
    }

    /// A HEIC ImageIO encodes with an ISO gain map from a small picture brighter than the standard range.
    @available(iOS 18, macOS 15, *)
    private static func isoGainMapPhoto() throws -> Data {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3))
        let floatInfo = CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
        let context = try #require(
            CGContext(
                data: nil,
                width: 16,
                height: 16,
                bitsPerComponent: 16,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | floatInfo
            )
        )
        context.setFillColor(try #require(CGColor(colorSpace: colorSpace, components: [3, 3, 3, 1])))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        let standardImage = try #require(context.makeImage())
        let image = try #require(CGImageCreateCopyWithContentHeadroom(4, standardImage))
        let data = try #require(CFDataCreateMutable(nil, 0))
        let type = UTType.heic.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithData(data, type, 1, nil))
        let request = [kCGImageDestinationEncodeRequest: kCGImageDestinationEncodeToISOGainmap] as CFDictionary
        CGImageDestinationAddImage(destination, image, request)
        try #require(CGImageDestinationFinalize(destination))
        return data as Data
    }

    // MARK: - Reading a copy

    /// The level of an auxiliary image of one-byte levels at a pixel, counted from the top left.
    static func level(of type: CFString, in url: URL, column: Int, row: Int) throws -> UInt8 {
        let pixels = try auxiliaryPixels(of: type, in: url)
        return pixels.data[pixels.data.startIndex + row * pixels.bytesPerRow + column]
    }

    /// The disparity of a file at a pixel, counted from the top left.
    static func disparity(in url: URL, column: Int, row: Int) throws -> Float {
        let pixels = try auxiliaryPixels(of: kCGImageAuxiliaryDataTypeDisparity, in: url)
        let offset = row * pixels.bytesPerRow + column * 4
        return pixels.data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Float.self) }
    }

    /// The pixels of an auxiliary image of a file.
    static func auxiliaryPixels(of type: CFString, in url: URL) throws -> AuxiliaryPixels {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let index = CGImageSourceGetPrimaryImageIndex(source)
        let info = try #require(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, index, type) as? [CFString: Any])
        return try AuxiliaryPixels(info: info, type: type)
    }

    /// The auxiliary image types a file has, of every type a fixture may have.
    static func auxiliaryTypes(in url: URL) throws -> [CFString] {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let index = CGImageSourceGetPrimaryImageIndex(source)
        return auxiliaryTypes().filter { CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, index, $0) != nil }
    }
}
