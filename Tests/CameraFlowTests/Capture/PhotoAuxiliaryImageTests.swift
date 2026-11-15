//
//  PhotoAuxiliaryImageTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Testing
@testable import CameraFlow

@Suite("Auxiliary images: the crop, the turn and the scale, and pixels that cannot be read")
struct PhotoAuxiliaryImageTests {
    private let type = kCGImageAuxiliaryDataTypePortraitEffectsMatte
    /// The photo is 8 x 4 and the auxiliary image 4 x 2: the middle 4 x 4 of the photo is its middle 2 x 2.
    private let frame = CGSize(width: 8, height: 4)
    private let rectangle = CGRect(x: 2, y: 0, width: 4, height: 4)

    private func description(pixelFormat: OSType, bytesPerRow: Int) -> [CFString: Any] {
        [
            "Width" as CFString: 4,
            "Height" as CFString: 2,
            "BytesPerRow" as CFString: bytesPerRow,
            "PixelFormat" as CFString: pixelFormat
        ]
    }

    @Test(
        "Pixels of two, four and eight bytes are cut whole, row by row",
        arguments: [
            (kCVPixelFormatType_OneComponent16Half, 2),
            (kCVPixelFormatType_OneComponent16, 2),
            (kCVPixelFormatType_DisparityFloat16, 2),
            (kCVPixelFormatType_OneComponent32Float, 4),
            (kCVPixelFormatType_32BGRA, 4),
            (kCVPixelFormatType_64RGBAHalf, 8)
        ]
    )
    func widePixels(pixelFormat: OSType, bytesPerPixel: Int) throws {
        // Every byte of a pixel holds the number of the pixel, counted row by row from zero, and a row has one
        // pixel of padding.
        let bytesPerRow = 5 * bytesPerPixel
        var pixels = Data()
        for pixel in 0..<10 {
            pixels.append(Data(repeating: UInt8(pixel), count: bytesPerPixel))
        }
        let info: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: pixels,
            kCGImageAuxiliaryDataInfoDataDescription: description(pixelFormat: pixelFormat, bytesPerRow: bytesPerRow)
        ]
        let cropped = try PhotoAuxiliaryImage.crop(info, type: type, to: rectangle, in: frame).get()
        let data = try #require(cropped[kCGImageAuxiliaryDataInfoData] as? Data)
        let expected = [1, 2, 6, 7].flatMap { [UInt8](repeating: UInt8($0), count: bytesPerPixel) }
        #expect(Array(data) == expected)
        let croppedDescription = try #require(cropped[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString: Any])
        #expect(croppedDescription["Width" as CFString] as? Int == 2)
        #expect(croppedDescription["Height" as CFString] as? Int == 2)
        #expect(croppedDescription["BytesPerRow" as CFString] as? Int == 2 * bytesPerPixel)
        #expect(croppedDescription["PixelFormat" as CFString] as? UInt32 == pixelFormat)
    }

    @Test("An auxiliary image without a description of its pixels is reported as malformed, not cut blindly")
    func noDescription() {
        let info: [CFString: Any] = [kCGImageAuxiliaryDataInfoData: Data(count: 16)]
        let result = PhotoAuxiliaryImage.crop(info, type: type, to: rectangle, in: frame)
        #expect(throws: PhotoAuxiliaryImage.CropFailure.unreadablePixels(.malformed(type as String))) {
            try result.get()
        }
    }

    @Test("An auxiliary image with fewer bytes than its description says is reported as malformed")
    func truncatedPixels() {
        let info: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: Data(count: 7),
            kCGImageAuxiliaryDataInfoDataDescription: description(
                pixelFormat: kCVPixelFormatType_OneComponent8,
                bytesPerRow: 4
            )
        ]
        let result = PhotoAuxiliaryImage.crop(info, type: type, to: rectangle, in: frame)
        #expect(throws: PhotoAuxiliaryImage.CropFailure.unreadablePixels(.malformed(type as String))) {
            try result.get()
        }
    }

    @Test(
        "An auxiliary image whose rows are shorter than their pixels is reported as malformed, not cut past its end",
        arguments: [
            (kCVPixelFormatType_OneComponent8, 3),
            (kCVPixelFormatType_OneComponent16Half, 4),
            (kCVPixelFormatType_32BGRA, 8)
        ]
    )
    func narrowRows(pixelFormat: OSType, bytesPerRow: Int) {
        // Enough bytes for the rows the description gives, which hold fewer bytes than four pixels of the format.
        let info: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: Data(count: bytesPerRow * 2),
            kCGImageAuxiliaryDataInfoDataDescription: description(pixelFormat: pixelFormat, bytesPerRow: bytesPerRow)
        ]
        let result = PhotoAuxiliaryImage.crop(info, type: type, to: rectangle, in: frame)
        #expect(throws: PhotoAuxiliaryImage.CropFailure.unreadablePixels(.malformed(type as String))) {
            try result.get()
        }
    }

    @Test("Each failure says what is wrong with which auxiliary image")
    func descriptions() {
        let name = type as String
        #expect(PhotoAuxiliaryImage.CropFailure.calibrated(name).description.hasPrefix(name))
        let malformed = PhotoAuxiliaryImage.CropFailure.unreadablePixels(.malformed(name))
        #expect(malformed.description == "\(name) has no readable pixel buffer")
        let unknown = PhotoAuxiliaryImage.CropFailure.unreadablePixels(.unknownPixelFormat(type: name, pixelFormat: 42))
        #expect(unknown.description == "\(name) has the unknown pixel format 42")
    }

    @Test("The auxiliary image types are the gain maps, then the mattes, depth and disparity, each once")
    func types() {
        let types = PhotoAuxiliaryImage.types
        #expect(Array(types.prefix(PhotoGainMap.types.count)) == PhotoGainMap.types)
        #expect(Set(types).count == types.count)
        #expect(types.contains(kCGImageAuxiliaryDataTypePortraitEffectsMatte))
        #expect(types.suffix(2) == [kCGImageAuxiliaryDataTypeDepth, kCGImageAuxiliaryDataTypeDisparity])
    }

    // MARK: - Upright

    /// Stored pixels of `bytesPerPixel` bytes and a pixel of padding a row, each holding its number, counted row by
    /// row from zero, in every byte.
    private func numberedInfo(
        width: Int,
        height: Int,
        bytesPerPixel: Int,
        pixelFormat: OSType,
        orientation: Int = 1
    ) -> [CFString: Any] {
        let bytesPerRow = (width + 1) * bytesPerPixel
        var pixels = Data()
        for row in 0..<height {
            for column in 0..<(width + 1) {
                pixels.append(Data(repeating: UInt8(row * width + min(column, width - 1)), count: bytesPerPixel))
            }
        }
        let description: [CFString: Any] = [
            "Width" as CFString: width,
            "Height" as CFString: height,
            "BytesPerRow" as CFString: bytesPerRow,
            "PixelFormat" as CFString: pixelFormat,
            "Orientation" as CFString: orientation
        ]
        return [
            kCGImageAuxiliaryDataInfoData: pixels,
            kCGImageAuxiliaryDataInfoDataDescription: description,
            kCGImageAuxiliaryDataInfoMetadata: "kept as it is"
        ]
    }

    /// Where a stored pixel lies in the upright picture: an EXIF orientation names the sides of the upright picture
    /// that the first stored row and the first stored column are.
    private static func uprightPixel(
        column: Int,
        row: Int,
        orientation: Int,
        uprightWidth: Int,
        uprightHeight: Int
    ) -> (column: Int, row: Int) {
        let right = uprightWidth - 1
        let bottom = uprightHeight - 1
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

    @Test(
        "Pixels of any format are turned whole, the way the orientation turns the photo, and keep their size",
        arguments: OrientedPhotoFixture.orientations
    )
    func upright(orientationValue: Int) throws {
        let orientation = try #require(CGImagePropertyOrientation(rawValue: UInt32(orientationValue)))
        let info = numberedInfo(
            width: 3,
            height: 2,
            bytesPerPixel: 2,
            pixelFormat: kCVPixelFormatType_DisparityFloat16,
            orientation: orientationValue
        )
        let type = kCGImageAuxiliaryDataTypeDisparity
        let turned = try PhotoAuxiliaryImage.upright(info, type: type, orientation: orientation, scale: 0.5).get()
        let isTurned = orientationValue >= 5
        let uprightWidth = isTurned ? 2 : 3
        let uprightHeight = isTurned ? 3 : 2
        var expected = [UInt8](repeating: 0, count: uprightWidth * uprightHeight * 2)
        for row in 0..<2 {
            for column in 0..<3 {
                let pixel = Self.uprightPixel(
                    column: column,
                    row: row,
                    orientation: orientationValue,
                    uprightWidth: uprightWidth,
                    uprightHeight: uprightHeight
                )
                let offset = (pixel.row * uprightWidth + pixel.column) * 2
                expected[offset] = UInt8(row * 3 + column)
                expected[offset + 1] = UInt8(row * 3 + column)
            }
        }
        let pixels = try AuxiliaryPixels(info: turned, type: type)
        #expect(pixels.width == uprightWidth)
        #expect(pixels.height == uprightHeight)
        #expect(pixels.pixelFormat == kCVPixelFormatType_DisparityFloat16)
        var rows = Data()
        for row in 0..<uprightHeight {
            let start = pixels.data.startIndex + row * pixels.bytesPerRow
            rows.append(pixels.data[start..<(start + uprightWidth * 2)])
        }
        #expect(rows == Data(expected))
        let description = try #require(turned[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString: Any])
        #expect(description["Orientation" as CFString] as? Int == 1)
        #expect(turned[kCGImageAuxiliaryDataInfoMetadata] as? String == "kept as it is")
    }

    @Test("One-byte pixels are scaled with the copy once turned, and never get smaller than one pixel")
    func uprightScaled() throws {
        let info = numberedInfo(width: 8, height: 6, bytesPerPixel: 1, pixelFormat: kCVPixelFormatType_OneComponent8)
        let type = kCGImageAuxiliaryDataTypePortraitEffectsMatte
        let half = try PhotoAuxiliaryImage.upright(info, type: type, orientation: .right, scale: 0.5).get()
        let description = try #require(half[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString: Any])
        #expect(description["Width" as CFString] as? Int == 3)
        #expect(description["Height" as CFString] as? Int == 4)
        #expect(description["BytesPerRow" as CFString] as? Int == 3)
        #expect((half[kCGImageAuxiliaryDataInfoData] as? Data)?.count == 12)
        let tiny = try PhotoAuxiliaryImage.upright(info, type: type, orientation: .up, scale: 0.01).get()
        #expect((tiny[kCGImageAuxiliaryDataInfoData] as? Data)?.count == 1)
    }

    @Test("An auxiliary image whose pixels cannot be read is reported, not turned blindly")
    func uprightUnreadable() {
        let type = kCGImageAuxiliaryDataTypeSemanticSegmentationSkyMatte
        let bare: [CFString: Any] = [kCGImageAuxiliaryDataInfoData: Data(count: 16)]
        #expect(throws: AuxiliaryPixels.Failure.malformed(type as String)) {
            try PhotoAuxiliaryImage.upright(bare, type: type, orientation: .right, scale: 1).get()
        }
        let unknown = numberedInfo(width: 2, height: 2, bytesPerPixel: 1, pixelFormat: 0x7834_3230)
        #expect(throws: AuxiliaryPixels.Failure.unknownPixelFormat(type: type as String, pixelFormat: 0x7834_3230)) {
            try PhotoAuxiliaryImage.upright(unknown, type: type, orientation: .right, scale: 1).get()
        }
        // Rows shorter than their pixels.
        let narrow: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: Data(count: 16),
            kCGImageAuxiliaryDataInfoDataDescription: description(
                pixelFormat: kCVPixelFormatType_OneComponent16Half,
                bytesPerRow: 4
            )
        ]
        #expect(throws: AuxiliaryPixels.Failure.malformed(type as String)) {
            try PhotoAuxiliaryImage.upright(narrow, type: type, orientation: .up, scale: 1).get()
        }
    }
}
