//
//  OrientedPhotoFixture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// A small photo file whose upright picture is four coloured quarters. The file stores the picture turned and
/// mirrored the way its EXIF orientation says, and carries EXIF, TIFF and GPS metadata.
enum OrientedPhotoFixture {
    /// A quarter of the upright picture, with a spot well inside it.
    enum Quarter: CaseIterable, Sendable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight

        var color: PixelGrid.Pixel {
            switch self {
            case .topLeft: PixelGrid.Pixel(red: 220, green: 40, blue: 40)
            case .topRight: PixelGrid.Pixel(red: 40, green: 180, blue: 60)
            case .bottomLeft: PixelGrid.Pixel(red: 40, green: 60, blue: 200)
            case .bottomRight: PixelGrid.Pixel(red: 230, green: 210, blue: 50)
            }
        }

        /// A spot of the quarter in upright pixels from the top left, away from the edges and from `overlay`.
        var spot: (column: Int, row: Int) {
            switch self {
            case .topLeft: (56, 40)
            case .topRight: (96, 24)
            case .bottomLeft: (32, 72)
            case .bottomRight: (96, 72)
            }
        }

        static func containing(column: Int, row: Int) -> Self {
            switch (column < uprightWidth / 2, row < uprightHeight / 2) {
            case (true, true): .topLeft
            case (false, true): .topRight
            case (true, false): .bottomLeft
            case (false, false): .bottomRight
            }
        }
    }

    static let uprightWidth = 128
    static let uprightHeight = 96
    static let orientations = Array(1...8)
    static let lensModel = "CameraFlow fixture lens"
    static let captureDate = "2026:11:06 10:15:30"
    static let latitude = 49.84

    /// A rectangle inside the top left quarter, in upright pixels from the top left, for a test to draw over.
    static let overlay = CGRect(x: 16, y: 16, width: 32, height: 16)
    static let overlaySpot = (column: 32, row: 24)

    /// `overlay` in the coordinates of a Core Graphics bitmap of the upright picture, which start at the bottom.
    static var overlayInBitmap: CGRect {
        CGRect(
            x: overlay.minX,
            y: CGFloat(uprightHeight) - overlay.maxY,
            width: overlay.width,
            height: overlay.height
        )
    }

    /// Writes the fixture as `name` with the extension of `type` into `directory`, which it creates.
    static func makeFile(orientation: Int, type: UTType, in directory: URL, name: String = "photo") throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileExtension = try #require(type.preferredFilenameExtension)
        let url = directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
        let image = try storedImage(orientation: orientation)
        let typeIdentifier = type.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, typeIdentifier, 1, nil))
        let properties = properties(orientation: orientation, width: image.width, height: image.height)
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        return url
    }

    /// The pixels the file stores: the upright picture read through the orientation backwards.
    private static func storedImage(orientation: Int) throws -> CGImage {
        let isTurned = orientation >= 5
        let width = isTurned ? uprightHeight : uprightWidth
        let height = isTurned ? uprightWidth : uprightHeight
        var bytes: [UInt8] = []
        bytes.reserveCapacity(width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let upright = uprightPixel(storedColumn: column, storedRow: row, orientation: orientation)
                let color = Quarter.containing(column: upright.column, row: upright.row).color
                bytes += [color.red, color.green, color.blue, 255]
            }
        }
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        return try #require(
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )
    }

    /// Where a stored pixel lies in the upright picture. An EXIF orientation names the sides of the upright
    /// picture that the first stored row and the first stored column are.
    private static func uprightPixel(
        storedColumn: Int,
        storedRow: Int,
        orientation: Int
    ) -> (column: Int, row: Int) {
        let right = uprightWidth - 1
        let bottom = uprightHeight - 1
        return switch orientation {
        case 2: (right - storedColumn, storedRow)
        case 3: (right - storedColumn, bottom - storedRow)
        case 4: (storedColumn, bottom - storedRow)
        case 5: (storedRow, storedColumn)
        case 6: (right - storedRow, storedColumn)
        case 7: (right - storedRow, bottom - storedColumn)
        case 8: (storedRow, bottom - storedColumn)
        default: (storedColumn, storedRow)
        }
    }

    private static func properties(orientation: Int, width: Int, height: Int) -> [CFString: Any] {
        [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 0.95,
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifLensModel: lensModel,
                kCGImagePropertyExifDateTimeOriginal: captureDate,
                kCGImagePropertyExifPixelXDimension: width,
                kCGImagePropertyExifPixelYDimension: height
            ] as [CFString: Any],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "CameraFlow",
                kCGImagePropertyTIFFModel: "Fixture"
            ] as [CFString: Any],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: latitude,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 24.03,
                kCGImagePropertyGPSLongitudeRef: "E"
            ] as [CFString: Any]
        ]
    }
}
