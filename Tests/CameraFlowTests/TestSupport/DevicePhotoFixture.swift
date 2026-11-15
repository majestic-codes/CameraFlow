//
//  DevicePhotoFixture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Testing

/// A small HEIF shaped like the device's: stored landscape with the portrait orientation tag, Display P3, EXIF, TIFF,
/// GPS and XMP metadata, and an HDR gain map at half the size. Sixteen bits per component encode as a 10-bit HEIF.
/// `makeCameraFile` is the file as AVFoundation writes it: no GPS, but the full EXIF and MakerApple sets.
enum DevicePhotoFixture {
    enum FixtureError: Error {
        case cannotEncode
        case unexpected
    }

    struct GainMap {
        let width: Int
        let height: Int
        let hasVersionTag: Bool
    }

    static let width = 256
    static let height = 192
    static let orientation = 6
    static let latitude = 50.45
    static let lensModel = "iPhone 17 Pro back triple camera 6.765mm f/1.78"
    static var xmpPath: CFString {
        "xmp:Label" as CFString
    }

    static let xmpValue = "CameraFlow fixture"
    static var dictionaryNames: [CFString] {
        [kCGImagePropertyExifDictionary, kCGImagePropertyTIFFDictionary, kCGImagePropertyGPSDictionary]
    }

    private static let gainMapNamespace = "http://ns.apple.com/HDRGainMap/1.0/"
    private static let gainMapPrefix = "HDRGainMap"

    static func make(bitsPerComponent: Int = 8) throws -> Data {
        try encode(properties: properties, bitsPerComponent: bitsPerComponent)
    }

    static func makeCameraFile(bitsPerComponent: Int = 8) throws -> Data {
        try encode(properties: cameraFileProperties, bitsPerComponent: bitsPerComponent)
    }

    private static func encode(properties: [CFString: Any], bitsPerComponent: Int) throws -> Data {
        let image = try makeImage(bitsPerComponent: bitsPerComponent)
        guard let data = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(data, "public.heic" as CFString, 1, nil) else {
            throw FixtureError.cannotEncode
        }
        let metadata = CGImageMetadataCreateMutable()
        guard CGImageMetadataSetValueWithPath(metadata, nil, xmpPath, xmpValue as CFString) else {
            throw FixtureError.cannotEncode
        }
        CGImageDestinationAddImageAndMetadata(destination, image, metadata, properties as CFDictionary)
        CGImageDestinationAddAuxiliaryDataInfo(destination, kCGImageAuxiliaryDataTypeHDRGainMap, try gainMapInfo())
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError.cannotEncode
        }
        return data as Data
    }

    static func properties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    /// The pixel bytes of the HDR gain map.
    static func gainMapData(of data: Data) throws -> Data {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let type = kCGImageAuxiliaryDataTypeHDRGainMap
        let info = try #require(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, type) as? [CFString: Any])
        return try #require(info[kCGImageAuxiliaryDataInfoData] as? Data)
    }

    static func gainMap(of data: Data) throws -> GainMap {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let type = kCGImageAuxiliaryDataTypeHDRGainMap
        let info = try #require(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, type) as? [CFString: Any])
        let description = try #require(info[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString: Any])
        let value = try #require(info[kCGImageAuxiliaryDataInfoMetadata] as CFTypeRef?)
        try #require(CFGetTypeID(value) == CGImageMetadataGetTypeID())
        let metadata = unsafeDowncast(value, to: CGImageMetadata.self)
        let versionPath = "\(gainMapPrefix):HDRGainMapVersion" as CFString
        let hasVersionTag = CGImageMetadataCopyTagWithPath(metadata, nil, versionPath) != nil
        return GainMap(
            width: try #require(description["Width" as CFString] as? Int),
            height: try #require(description["Height" as CFString] as? Int),
            hasVersionTag: hasVersionTag
        )
    }

    private static var properties: [CFString: Any] {
        [
            kCGImagePropertyOrientation: orientation,
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifLensModel: lensModel,
                kCGImagePropertyExifFNumber: 1.78,
                kCGImagePropertyExifISOSpeedRatings: [80],
                kCGImagePropertyExifDateTimeOriginal: "2026:11:05 18:20:04",
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
                kCGImagePropertyGPSLongitude: 30.52,
                kCGImagePropertyGPSLongitudeRef: "E"
            ] as [CFString: Any]
        ]
    }

    /// The keys the device's file writer adds on top of `AVCapturePhoto.metadata`, among the ones it has too.
    private static var cameraFileProperties: [CFString: Any] {
        let exif: [CFString: Any] = [
            kCGImagePropertyExifLensModel: lensModel,
            kCGImagePropertyExifLensMake: "Apple",
            kCGImagePropertyExifFNumber: 1.78,
            kCGImagePropertyExifApertureValue: 1.6637,
            kCGImagePropertyExifBrightnessValue: -2.41,
            kCGImagePropertyExifExposureTime: 1.0 / 60,
            kCGImagePropertyExifExposureBiasValue: 0,
            kCGImagePropertyExifExposureMode: 0,
            kCGImagePropertyExifExposureProgram: 2,
            kCGImagePropertyExifShutterSpeedValue: 5.907,
            kCGImagePropertyExifFocalLength: 6.765,
            kCGImagePropertyExifFocalLenIn35mmFilm: 24,
            kCGImagePropertyExifISOSpeedRatings: [800],
            kCGImagePropertyExifSubjectArea: [2014, 1512, 2218, 1331],
            kCGImagePropertyExifLensSpecification: [2.22, 16.89, 1.78, 2.8],
            kCGImagePropertyExifWhiteBalance: 0,
            kCGImagePropertyExifMeteringMode: 5,
            kCGImagePropertyExifFlash: 16,
            kCGImagePropertyExifDateTimeOriginal: "2026:11:05 18:20:04",
            kCGImagePropertyExifSubsecTimeOriginal: "614",
            kCGImagePropertyExifOffsetTimeOriginal: "+00:00",
            kCGImagePropertyExifPixelXDimension: width,
            kCGImagePropertyExifPixelYDimension: height
        ]
        let makerApple: [String: Any] = [
            "1": 17,
            "3": ["flags": 1, "value": 2_871_266_281_083, "timescale": 1_000_000_000, "epoch": 0],
            "8": [0.012, -0.81, -0.59],
            "20": 4,
            "23": 8_192,
            "25": 0,
            "31": 0,
            "43": "8F5A3B2C-0D1E-4F60-9A7B-8C9D0E1F2A3B",
            "60": 4,
            "65": 0
        ]
        return [
            kCGImagePropertyOrientation: orientation,
            kCGImagePropertyExifDictionary: exif,
            kCGImagePropertyMakerAppleDictionary: makerApple,
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Apple",
                kCGImagePropertyTIFFModel: "iPhone 17 Pro",
                kCGImagePropertyTIFFSoftware: "27.2",
                kCGImagePropertyTIFFDateTime: "2026:11:05 18:20:04",
                kCGImagePropertyTIFFHostComputer: "iPhone 17 Pro"
            ] as [CFString: Any]
        ]
    }

    private static func makeImage(bitsPerComponent: Int) throws -> CGImage {
        let byteOrder = bitsPerComponent == 16 ? CGBitmapInfo.byteOrder16Little.rawValue : 0
        guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: bitsPerComponent,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | byteOrder
              ) else {
            throw FixtureError.cannotEncode
        }
        context.setFillColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            throw FixtureError.cannotEncode
        }
        return image
    }

    private static func gainMapInfo() throws -> CFDictionary {
        let gainWidth = width / 2
        let gainHeight = height / 2
        let metadata = CGImageMetadataCreateMutable()
        guard CGImageMetadataRegisterNamespaceForPrefix(
            metadata,
            gainMapNamespace as CFString,
            gainMapPrefix as CFString,
            nil
        ) else {
            throw FixtureError.cannotEncode
        }
        let versionPath = "\(gainMapPrefix):HDRGainMapVersion" as CFString
        guard CGImageMetadataSetValueWithPath(metadata, nil, versionPath, 131_072 as CFNumber) else {
            throw FixtureError.cannotEncode
        }
        let description: [CFString: Any] = [
            "Width" as CFString: gainWidth,
            "Height" as CFString: gainHeight,
            "BytesPerRow" as CFString: gainWidth,
            "PixelFormat" as CFString: kCVPixelFormatType_OneComponent8
        ]
        let pixels = Data((0..<(gainWidth * gainHeight)).map { UInt8($0 % 251) })
        let info: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: pixels,
            kCGImageAuxiliaryDataInfoDataDescription: description,
            kCGImageAuxiliaryDataInfoMetadata: metadata
        ]
        return info as CFDictionary
    }
}
