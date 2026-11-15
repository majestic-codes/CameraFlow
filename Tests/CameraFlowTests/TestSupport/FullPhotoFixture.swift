//
//  FullPhotoFixture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A photo with everything a native photo of the device holds, and the XMP a photo edited elsewhere may hold: the
/// camera's EXIF (with its subject area), TIFF and MakerApple sets, a GPS dictionary, an XMP label, a Camera Raw
/// setting and a tag of a namespace of its own, an HDR gain map at half the size and a portrait effects matte at a
/// quarter. Stored landscape with the portrait orientation tag, in Display P3. `makeStereoPair` is a spatial photo:
/// two such images in a stereo pair group, each eye with its own lens and camera position.
enum FullPhotoFixture {
    enum FixtureError: Error {
        case cannotEncode
    }

    static let width = 256
    static let height = 192
    static let orientation = 6
    static let subjectArea = [128, 96, 100, 60]
    static let disparityAdjustment = 200
    /// The XMP tags no property dictionary holds, by path, with their values.
    static let xmpTags = [
        "xmp:Label": "CameraFlow fixture",
        "crs:Exposure2012": "+0.35",
        "cfx:Custom": "kept"
    ]
    static let lensModels = (left: "main camera lens", right: "ultra wide camera lens")

    private static let namespaces = [
        "crs": "http://ns.adobe.com/camera-raw-settings/1.0/",
        "cfx": "http://example.com/cameraflow-fixture/1.0/"
    ]

    static func make(type: UTType = .heic, width: Int = width, height: Int = height) throws -> Data {
        try encode(type: type, imageCount: 1) { destination in
            let image = try makeImage(width: width, height: height)
            let properties = properties(width: width, height: height, lensModel: lensModels.left)
            CGImageDestinationAddImageAndMetadata(destination, image, try metadata(), properties as CFDictionary)
            try addAuxiliaryImages(width: width, height: height, to: destination)
        }
    }

    static func makeStereoPair() throws -> Data {
        try encode(type: .heic, imageCount: 2) { destination in
            for isLeft in [true, false] {
                let image = try makeImage(width: width, height: height)
                var properties = properties(
                    width: width,
                    height: height,
                    lensModel: isLeft ? lensModels.left : lensModels.right
                )
                properties[kCGImagePropertyGroups] = [
                    kCGImagePropertyGroupIndex: 0,
                    kCGImagePropertyGroupType: kCGImagePropertyGroupTypeStereoPair,
                    kCGImagePropertyGroupImageDisparityAdjustment: disparityAdjustment,
                    isLeft ? kCGImagePropertyGroupImageIsLeftImage : kCGImagePropertyGroupImageIsRightImage: true
                ] as [CFString: Any]
                properties[kCGImagePropertyHEIFDictionary] = [
                    kIIOMetadata_CameraExtrinsicsKey: [
                        kIIOCameraExtrinsics_Position: [isLeft ? 0 : 0.0195, 0, 0],
                        kIIOCameraExtrinsics_Rotation: [1, 0, 0, 0, 1, 0, 0, 0, 1]
                    ] as [CFString: Any]
                ] as [CFString: Any]
                CGImageDestinationAddImageAndMetadata(destination, image, try metadata(), properties as CFDictionary)
                try addAuxiliaryImages(width: width, height: height, to: destination)
            }
        }
    }

    private static func encode(
        type: UTType,
        imageCount: Int,
        addImages: (CGImageDestination) throws -> Void
    ) throws -> Data {
        let typeIdentifier = type.identifier as CFString
        guard let data = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(data, typeIdentifier, imageCount, nil) else {
            throw FixtureError.cannotEncode
        }
        try addImages(destination)
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError.cannotEncode
        }
        return data as Data
    }

    private static func properties(width: Int, height: Int, lensModel: String) -> [CFString: Any] {
        let exif: [CFString: Any] = [
            kCGImagePropertyExifLensModel: lensModel,
            kCGImagePropertyExifLensMake: "Apple",
            kCGImagePropertyExifFNumber: 1.78,
            kCGImagePropertyExifExposureTime: 1.0 / 60,
            kCGImagePropertyExifFocalLength: 6.765,
            kCGImagePropertyExifFocalLenIn35mmFilm: 24,
            kCGImagePropertyExifISOSpeedRatings: [800],
            kCGImagePropertyExifSubjectArea: subjectArea,
            kCGImagePropertyExifLensSpecification: [2.22, 16.89, 1.78, 2.8],
            kCGImagePropertyExifFlash: 16,
            kCGImagePropertyExifColorSpace: 65_535,
            kCGImagePropertyExifDateTimeOriginal: "2026:11:05 18:20:04",
            kCGImagePropertyExifSubsecTimeOriginal: "614",
            kCGImagePropertyExifOffsetTimeOriginal: "+00:00",
            kCGImagePropertyExifPixelXDimension: width,
            kCGImagePropertyExifPixelYDimension: height
        ]
        let makerApple: [String: Any] = [
            "1": 17,
            "8": [0.012, -0.81, -0.59],
            "17": "5D8F1E0A-3B7C-4D2E-9F61-0A1B2C3D4E5F",
            "43": "8F5A3B2C-0D1E-4F60-9A7B-8C9D0E1F2A3B"
        ]
        return [
            kCGImagePropertyOrientation: orientation,
            kCGImagePropertyExifDictionary: exif,
            kCGImagePropertyMakerAppleDictionary: makerApple,
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Apple",
                kCGImagePropertyTIFFModel: "iPhone 17 Pro",
                kCGImagePropertyTIFFSoftware: "27.2",
                kCGImagePropertyTIFFDateTime: "2026:11:05 18:20:04"
            ] as [CFString: Any],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 50.45,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 30.52,
                kCGImagePropertyGPSLongitudeRef: "E",
                kCGImagePropertyGPSImgDirection: 92.5,
                kCGImagePropertyGPSImgDirectionRef: "T"
            ] as [CFString: Any]
        ]
    }

    private static func metadata() throws -> CGImageMetadata {
        let metadata = CGImageMetadataCreateMutable()
        for (prefix, namespace) in namespaces {
            guard CGImageMetadataRegisterNamespaceForPrefix(metadata, namespace as CFString, prefix as CFString, nil)
            else {
                throw FixtureError.cannotEncode
            }
        }
        for (path, value) in xmpTags {
            guard CGImageMetadataSetValueWithPath(metadata, nil, path as CFString, value as CFString) else {
                throw FixtureError.cannotEncode
            }
        }
        return metadata
    }

    private static func makeImage(width: Int, height: Int) throws -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw FixtureError.cannotEncode
        }
        context.setFillColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        guard let image = context.makeImage() else {
            throw FixtureError.cannotEncode
        }
        return image
    }

    /// The HDR gain map at half the size of the photo and the portrait effects matte at a quarter.
    private static func addAuxiliaryImages(width: Int, height: Int, to destination: CGImageDestination) throws {
        let gainMap = try oneByteImage(
            width: width / 2,
            height: height / 2,
            namespace: "http://ns.apple.com/HDRGainMap/1.0/",
            versionPath: "HDRGainMap:HDRGainMapVersion"
        )
        CGImageDestinationAddAuxiliaryDataInfo(destination, kCGImageAuxiliaryDataTypeHDRGainMap, gainMap)
        let matte = try oneByteImage(
            width: width / 4,
            height: height / 4,
            namespace: "http://ns.apple.com/PortraitEffectsMatte/1.0/",
            versionPath: "PortraitEffectsMatte:PortraitEffectsMatteVersion"
        )
        CGImageDestinationAddAuxiliaryDataInfo(destination, kCGImageAuxiliaryDataTypePortraitEffectsMatte, matte)
    }

    /// An auxiliary image of one byte per pixel, with its version tag in its own metadata.
    private static func oneByteImage(
        width: Int,
        height: Int,
        namespace: String,
        versionPath: String
    ) throws -> CFDictionary {
        let metadata = CGImageMetadataCreateMutable()
        let prefix = String(versionPath.prefix { $0 != ":" })
        guard CGImageMetadataRegisterNamespaceForPrefix(metadata, namespace as CFString, prefix as CFString, nil),
              CGImageMetadataSetValueWithPath(metadata, nil, versionPath as CFString, 65_536 as CFNumber) else {
            throw FixtureError.cannotEncode
        }
        let description: [CFString: Any] = [
            "Width" as CFString: width,
            "Height" as CFString: height,
            "BytesPerRow" as CFString: width,
            "PixelFormat" as CFString: kCVPixelFormatType_OneComponent8
        ]
        let info: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: Data((0..<(width * height)).map { UInt8($0 % 251) }),
            kCGImageAuxiliaryDataInfoDataDescription: description,
            kCGImageAuxiliaryDataInfoMetadata: metadata
        ]
        return info as CFDictionary
    }
}
