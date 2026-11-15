//
//  DualCameraFixture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// Photos for the dual camera tests: a main photo of a flat colour in any upright size, and a frame for the circle of
/// another colour with a mark in the top left corner of its upright picture. Both store their pixels turned and
/// mirrored the way their EXIF orientation says, and the main photo carries EXIF, TIFF and GPS metadata.
enum DualCameraFixture {
    static let mainColor = PixelGrid.Pixel(red: 40, green: 60, blue: 200)
    static let circleColor = PixelGrid.Pixel(red: 230, green: 140, blue: 50)
    static let markColor = PixelGrid.Pixel(red: 250, green: 250, blue: 250)
    /// The mark of the circle's frame in its upright picture, in unit coordinates from the top left.
    static let mark = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
    static let lensModel = "CameraFlow dual fixture lens"
    static let latitude = 50.45
    /// The circle where the 402 x 874 screen lays it out over a 4:3 viewfinder.
    static let circleOnScreen: DualCameraCircle = {
        let layout = LayoutWindow.referencePhone.layout(panelTileCount: 6)
        guard let placement = layout.dualCameraCirclePlacement else {
            preconditionFailure("The 402 x 874 screen lays the circle out")
        }
        return placement
    }()
    /// HEIF without Live Photo: an initial state that keeps every setting the pair offers.
    static let keptState = CameraFlowInitialState()

    /// A circle that sits as the screen draws it, with a rim and a shadow too thin to reach a spot it is checked at.
    static func circle(region: CGRect) -> DualCameraCircle {
        DualCameraCircle(region: region, rimWidthRatio: 0.01, rimOpacity: 0.85, shadowRadiusRatio: 0, shadowOpacity: 0)
    }

    /// Writes a main photo of `uprightSize` into `directory`, stored with the orientation.
    static func makeMainPhoto(
        uprightSize: (width: Int, height: Int),
        orientation: Int,
        type: UTType,
        in directory: URL
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileExtension = try #require(type.preferredFilenameExtension)
        let url = directory.appendingPathComponent("main").appendingPathExtension(fileExtension)
        let image = try storedImage(uprightSize: uprightSize, orientation: orientation) { _, _ in mainColor }
        let typeIdentifier = type.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, typeIdentifier, 1, nil))
        CGImageDestinationAddImage(destination, image, mainProperties(orientation: orientation) as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        return url
    }

    /// A frame for the circle of `uprightSize`, stored with the orientation, taken beside a main camera that the
    /// viewfinder showed mirrored when asked.
    static func makeCircleFrame(
        uprightSize: (width: Int, height: Int),
        orientation: Int,
        isViewfinderMirrored: Bool = false,
        viewfinderQuarterTurns: Int
    ) throws -> CircleCameraFrame {
        let image = try storedImage(uprightSize: uprightSize, orientation: orientation) { column, row in
            let unitX = (Double(column) + 0.5) / Double(uprightSize.width)
            let unitY = (Double(row) + 0.5) / Double(uprightSize.height)
            return mark.contains(CGPoint(x: unitX, y: unitY)) ? markColor : circleColor
        }
        let data = try #require(CFDataCreateMutable(nil, 0))
        let jpegIdentifier = UTType.jpeg.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithData(data, jpegIdentifier, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 0.95
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        return CircleCameraFrame(
            imageData: data as Data,
            isViewfinderMirrored: isViewfinderMirrored,
            viewfinderQuarterTurns: viewfinderQuarterTurns
        )
    }

    /// The pixels a file stores: the upright picture read through the orientation backwards.
    private static func storedImage(
        uprightSize: (width: Int, height: Int),
        orientation: Int,
        pixel: (Int, Int) -> PixelGrid.Pixel
    ) throws -> CGImage {
        let isTurned = orientation >= 5
        let width = isTurned ? uprightSize.height : uprightSize.width
        let height = isTurned ? uprightSize.width : uprightSize.height
        var bytes: [UInt8] = []
        bytes.reserveCapacity(width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let upright = uprightPixel(
                    storedColumn: column,
                    storedRow: row,
                    orientation: orientation,
                    uprightSize: uprightSize
                )
                let color = pixel(upright.column, upright.row)
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
        orientation: Int,
        uprightSize: (width: Int, height: Int)
    ) -> (column: Int, row: Int) {
        let right = uprightSize.width - 1
        let bottom = uprightSize.height - 1
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

    private static func mainProperties(orientation: Int) -> [CFString: Any] {
        [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 0.95,
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifLensModel: lensModel] as [CFString: Any],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "Dual fixture"] as [CFString: Any],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: latitude,
                kCGImagePropertyGPSLatitudeRef: "N"
            ] as [CFString: Any]
        ]
    }
}
