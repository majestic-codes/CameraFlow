//
//  SimulatedPhotoFile.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreVideo
import Foundation
import ImageIO

/// A photo file of the simulated camera, shaped like the device's: a 4:3 frame stored landscape with the portrait
/// orientation tag, in Display P3, with the EXIF, TIFF and MakerApple sets the camera writes and an HDR gain map at
/// half its size. The gain map boosts nothing: the simulated scene has no highlights. Like the device's file, it
/// has no GPS dictionary.
struct SimulatedPhotoFile: Sendable {
    /// What the frame shows.
    enum Picture: Sendable {
        /// The flat colour of the scene.
        case flat(CGColor)
        /// One camera of the dual camera, or the front camera alone, as the camera took it: a photo is never mirrored.
        case dualCamera(SimulatedDualPicture)
    }

    let picture: Picture
    /// The type of the file: HEIC where ImageIO encodes HEVC, JPEG otherwise.
    let typeIdentifier: String
    /// The lens the EXIF names.
    let lensModel: String

    static let longSide = 256
    static let shortSide = 192
    /// EXIF orientation "rotate 90 clockwise to show": a portrait photo from a landscape sensor.
    static let portraitOrientation = 6

    /// The encoded file. It takes a while, so the camera calls it off the main actor.
    func encoded() throws -> Data {
        let image = try render()
        let gainMap = try gainMap()
        do {
            return try ImageEncoding.data(typeIdentifier: typeIdentifier) { destination in
                CGImageDestinationAddImage(destination, image, properties as CFDictionary)
                CGImageDestinationAddAuxiliaryDataInfo(destination, kCGImageAuxiliaryDataTypeHDRGainMap, gainMap)
            }
        } catch {
            throw CameraServiceError.captureFailed("Cannot encode the simulated photo: \(error)")
        }
    }

    private func render() throws -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(
                  data: nil,
                  width: Self.longSide,
                  height: Self.shortSide,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else {
            throw CameraServiceError.captureFailed("Cannot create a bitmap for the simulated photo")
        }
        switch picture {
        case let .flat(color):
            context.setFillColor(color)
            context.fill(CGRect(x: 0, y: 0, width: Self.longSide, height: Self.shortSide))
        case let .dualCamera(picture):
            picture.drawStored(in: context, width: Self.longSide, height: Self.shortSide)
        }
        guard let image = context.makeImage() else {
            throw CameraServiceError.captureFailed("Cannot render the simulated photo")
        }
        return image
    }

    /// The property dictionaries the device's file writer adds to the camera's metadata, with the values of a
    /// simulated shot.
    private var properties: [CFString: Any] {
        // A rectangle in the middle of the frame: its centre, width and height.
        let subjectArea = [Self.longSide / 2, Self.shortSide / 2, Self.longSide / 2, Self.shortSide / 2]
        let exif: [CFString: Any] = [
            kCGImagePropertyExifLensModel: lensModel,
            kCGImagePropertyExifLensMake: "Apple",
            kCGImagePropertyExifFNumber: 1.78,
            kCGImagePropertyExifExposureTime: 1.0 / 60,
            kCGImagePropertyExifISOSpeedRatings: [100],
            kCGImagePropertyExifFocalLength: 6.765,
            kCGImagePropertyExifFocalLenIn35mmFilm: 24,
            kCGImagePropertyExifSubjectArea: subjectArea,
            kCGImagePropertyExifFlash: 16,
            kCGImagePropertyExifWhiteBalance: 0,
            kCGImagePropertyExifExposureMode: 0,
            kCGImagePropertyExifPixelXDimension: Self.longSide,
            kCGImagePropertyExifPixelYDimension: Self.shortSide
        ]
        // The keys of MakerApple are its tag numbers.
        let makerApple: [String: Any] = ["1": 17, "20": 4, "25": 0, "31": 0, "60": 4]
        return [
            kCGImagePropertyOrientation: Self.portraitOrientation,
            kCGImagePropertyExifDictionary: exif,
            kCGImagePropertyMakerAppleDictionary: makerApple,
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Apple",
                kCGImagePropertyTIFFModel: "iPhone 17 Pro",
                kCGImagePropertyTIFFSoftware: "CameraFlow simulated camera"
            ] as [CFString: Any]
        ]
    }

    /// A flat gain map of one byte per pixel at half the size, with its version in its own metadata.
    private func gainMap() throws -> CFDictionary {
        let width = Self.longSide / 2
        let height = Self.shortSide / 2
        let metadata = CGImageMetadataCreateMutable()
        let namespace = "http://ns.apple.com/HDRGainMap/1.0/" as CFString
        let versionPath = "HDRGainMap:HDRGainMapVersion" as CFString
        guard CGImageMetadataRegisterNamespaceForPrefix(metadata, namespace, "HDRGainMap" as CFString, nil),
              CGImageMetadataSetValueWithPath(metadata, nil, versionPath, 131_072 as CFNumber) else {
            throw CameraServiceError.captureFailed("Cannot describe the gain map of the simulated photo")
        }
        let description: [CFString: Any] = [
            "Width" as CFString: width,
            "Height" as CFString: height,
            "BytesPerRow" as CFString: width,
            "PixelFormat" as CFString: kCVPixelFormatType_OneComponent8
        ]
        let info: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: Data(count: width * height),
            kCGImageAuxiliaryDataInfoDataDescription: description,
            kCGImageAuxiliaryDataInfoMetadata: metadata
        ]
        return info as CFDictionary
    }
}
