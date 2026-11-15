//
//  StaleThumbnailFixture.swift
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

/// A JPEG whose image and whose embedded Exif thumbnail show different colours, as a photo edited in Photos can
/// be left with the thumbnail of the original.
enum StaleThumbnailFixture {
    static let imageColor = PixelGrid.Pixel(red: 255, green: 0, blue: 0)
    static let thumbnailColor = PixelGrid.Pixel(red: 0, green: 0, blue: 255)

    static func makeFile(in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("stale.jpeg")
        let image = try makeJPEG(width: 600, height: 450, color: imageColor)
        let thumbnail = try makeJPEG(width: 40, height: 30, color: thumbnailColor)
        try insertExifThumbnail(thumbnail, into: image).write(to: url)
        return url
    }

    private static func makeJPEG(width: Int, height: Int, color: PixelGrid.Pixel) throws -> Data {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: 1
        )
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = try #require(CFDataCreateMutable(nil, 0))
        let type = UTType.jpeg.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithData(data, type, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return data as Data
    }

    /// Puts an Exif segment right after the start of the image whose second directory, the one of the thumbnail,
    /// holds `thumbnail`.
    private static func insertExifThumbnail(_ thumbnail: Data, into jpeg: Data) throws -> Data {
        let headerLength: UInt32 = 8
        let emptyDirectoryLength: UInt32 = 6
        let thumbnailDirectoryLength: UInt32 = 2 + 2 * 12 + 4
        let thumbnailOffset = headerLength + emptyDirectoryLength + thumbnailDirectoryLength
        var tiff = Data([0x4D, 0x4D, 0x00, 0x2A])
        tiff.append(bigEndian: headerLength)
        tiff.append(bigEndian: UInt16(0))
        tiff.append(bigEndian: headerLength + emptyDirectoryLength)
        tiff.append(bigEndian: UInt16(2))
        for (tag, value) in [(UInt16(0x0201), thumbnailOffset), (UInt16(0x0202), UInt32(thumbnail.count))] {
            tiff.append(bigEndian: tag)
            tiff.append(bigEndian: UInt16(4))
            tiff.append(bigEndian: UInt32(1))
            tiff.append(bigEndian: value)
        }
        tiff.append(bigEndian: UInt32(0))
        tiff.append(thumbnail)
        let identifier = Data("Exif".utf8) + Data([0, 0])
        var segment = Data([0xFF, 0xE1])
        segment.append(bigEndian: UInt16(2 + identifier.count + tiff.count))
        segment.append(identifier)
        segment.append(tiff)
        return jpeg.prefix(2) + segment + jpeg.dropFirst(2)
    }
}

private extension Data {

    mutating func append<Value: FixedWidthInteger>(bigEndian value: Value) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }
}
