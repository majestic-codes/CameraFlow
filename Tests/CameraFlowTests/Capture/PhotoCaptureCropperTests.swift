//
//  PhotoCaptureCropperTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("Photo capture cropper")
struct PhotoCaptureCropperTests {

    @Test(
        "The crop is centred and keeps the ratio on the long and short side",
        arguments: [
            (4032, 3024, CameraFlowAspectRatio.fourByThree, CGRect(x: 0, y: 0, width: 4032, height: 3024)),
            (4032, 3024, CameraFlowAspectRatio.sixteenByNine, CGRect(x: 0, y: 378, width: 4032, height: 2268)),
            (4032, 3024, CameraFlowAspectRatio.square, CGRect(x: 504, y: 0, width: 3024, height: 3024)),
            (3024, 4032, CameraFlowAspectRatio.sixteenByNine, CGRect(x: 378, y: 0, width: 2268, height: 4032)),
            (3024, 4032, CameraFlowAspectRatio.square, CGRect(x: 0, y: 504, width: 3024, height: 3024))
        ]
    )
    func rectangle(width: Int, height: Int, aspectRatio: CameraFlowAspectRatio, expected: CGRect) {
        #expect(PhotoCaptureCropper.cropRectangle(width: width, height: height, aspectRatio: aspectRatio) == expected)
    }

    @Test("A photo already in the ratio is left as it is")
    func unchanged() throws {
        let data = try DevicePhotoFixture.make()
        #expect(try PhotoCaptureCropper.crop(data, to: .fourByThree) == .unchanged)
    }

    @Test(
        "A cropped photo keeps its orientation tag and has the ratio upright",
        arguments: [(CameraFlowAspectRatio.sixteenByNine, 144, 256), (.square, 192, 192)]
    )
    func orientation(aspectRatio: CameraFlowAspectRatio, uprightWidth: Int, uprightHeight: Int) throws {
        let cropped = try croppedFile(to: aspectRatio)
        let properties = try DevicePhotoFixture.properties(of: cropped)
        #expect(properties[kCGImagePropertyOrientation] as? Int == DevicePhotoFixture.orientation)
        // Orientation 6 turns the stored frame a quarter, so the upright width is the stored height.
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == uprightWidth)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == uprightHeight)
    }

    @Test("A cropped photo has every property dictionary and key of the original", arguments: croppedRatios)
    func propertiesKept(aspectRatio: CameraFlowAspectRatio) throws {
        let photo = try DevicePhotoFixture.make()
        let croppedPhoto = try croppedFile(to: aspectRatio)
        let original = try DevicePhotoFixture.properties(of: photo)
        let cropped = try DevicePhotoFixture.properties(of: croppedPhoto)
        for name in DevicePhotoFixture.dictionaryNames {
            let originalDictionary = try #require(original[name] as? [CFString: Any])
            let croppedDictionary = try #require(cropped[name] as? [CFString: Any])
            #expect(Set(croppedDictionary.keys) == Set(originalDictionary.keys))
        }
        let gps = try #require(cropped[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        #expect(gps[kCGImagePropertyGPSLatitude] as? Double == DevicePhotoFixture.latitude)
        let exif = try #require(cropped[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifLensModel] as? String == DevicePhotoFixture.lensModel)
        #expect(exif[kCGImagePropertyExifPixelXDimension] as? Int == cropped[kCGImagePropertyPixelWidth] as? Int)
        #expect(exif[kCGImagePropertyExifPixelYDimension] as? Int == cropped[kCGImagePropertyPixelHeight] as? Int)
    }

    @Test("A cropped photo keeps the colour profile and the bit depth", arguments: croppedRatios)
    func colourKept(aspectRatio: CameraFlowAspectRatio) throws {
        let photo = try DevicePhotoFixture.make()
        let croppedPhoto = try croppedFile(to: aspectRatio)
        let original = try DevicePhotoFixture.properties(of: photo)
        let cropped = try DevicePhotoFixture.properties(of: croppedPhoto)
        #expect(cropped[kCGImagePropertyProfileName] as? String == original[kCGImagePropertyProfileName] as? String)
        #expect(cropped[kCGImagePropertyProfileName] as? String == "Display P3")
        #expect(cropped[kCGImagePropertyDepth] as? Int == original[kCGImagePropertyDepth] as? Int)
    }

    @Test("A 10-bit photo stays 10-bit", arguments: croppedRatios)
    func tenBitKept(aspectRatio: CameraFlowAspectRatio) throws {
        let original = try DevicePhotoFixture.make(bitsPerComponent: 16)
        #expect(try DevicePhotoFixture.properties(of: original)[kCGImagePropertyDepth] as? Int == 10)
        guard case let .cropped(cropped) = try PhotoCaptureCropper.crop(original, to: aspectRatio) else {
            Issue.record("Expected a cropped photo")
            return
        }
        #expect(try DevicePhotoFixture.properties(of: cropped)[kCGImagePropertyDepth] as? Int == 10)
    }

    @Test("A cropped photo keeps the XMP of the original", arguments: croppedRatios)
    func xmpKept(aspectRatio: CameraFlowAspectRatio) throws {
        let cropped = try croppedFile(to: aspectRatio)
        let source = try #require(CGImageSourceCreateWithData(cropped as CFData, nil))
        let metadata = try #require(CGImageSourceCopyMetadataAtIndex(source, 0, nil))
        let value = CGImageMetadataCopyStringValueWithPath(metadata, nil, DevicePhotoFixture.xmpPath)
        #expect(value as String? == DevicePhotoFixture.xmpValue)
    }

    @Test("The gain map is cropped to the same region, its metadata kept", arguments: croppedRatios)
    func gainMapCropped(aspectRatio: CameraFlowAspectRatio) throws {
        let cropped = try croppedFile(to: aspectRatio)
        let properties = try DevicePhotoFixture.properties(of: cropped)
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        let gainMap = try DevicePhotoFixture.gainMap(of: cropped)
        // The fixture's gain map is half the photo on each side.
        #expect(gainMap.width == width / 2)
        #expect(gainMap.height == height / 2)
        #expect(gainMap.hasVersionTag)
    }

    @Test(
        "A cropped photo has its subject area in the cropped frame",
        arguments: [(CameraFlowAspectRatio.square, [96, 96, 100, 60]), (.sixteenByNine, [128, 72, 100, 60])]
    )
    func subjectAreaCropped(aspectRatio: CameraFlowAspectRatio, expected: [Int]) throws {
        let photo = try FullPhotoFixture.make()
        let outcome = try PhotoCaptureCropper.crop(photo, to: aspectRatio)
        guard case let .cropped(cropped) = outcome else {
            Issue.record("Expected a cropped photo, got \(outcome)")
            return
        }
        let properties = try DevicePhotoFixture.properties(of: cropped)
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifSubjectArea] as? [Int] == expected)
    }

    @Test("A cropped photo keeps every property and every XMP tag of the camera's", arguments: croppedRatios)
    func everythingKept(aspectRatio: CameraFlowAspectRatio) throws {
        let original = try FullPhotoFixture.make()
        let outcome = try PhotoCaptureCropper.crop(original, to: aspectRatio)
        guard case let .cropped(cropped) = outcome else {
            Issue.record("Expected a cropped photo, got \(outcome)")
            return
        }
        try MetadataExpectations.expectKept(from: original, in: cropped)
        for (path, value) in FullPhotoFixture.xmpTags {
            #expect(try MetadataExpectations.xmpValue(at: path, of: cropped) == value, "\(path)")
        }
    }

    @Test("A cropped photo carries a thumbnail of its own pixels", arguments: croppedRatios)
    func thumbnail(aspectRatio: CameraFlowAspectRatio) throws {
        let cropped = try croppedFile(to: aspectRatio)
        let source = try #require(CGImageSourceCreateWithData(cropped as CFData, nil))
        let options = [kCGImageSourceCreateThumbnailFromImageIfAbsent: false] as CFDictionary
        let thumbnail = try #require(CGImageSourceCreateThumbnailAtIndex(source, 0, options))
        let properties = try DevicePhotoFixture.properties(of: cropped)
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        // The thumbnail has the ratio of the cropped photo, within a pixel.
        #expect(abs(thumbnail.width * height - thumbnail.height * width) <= max(width, height))
    }

    @Test("Depth data is not cropped: the photo is reported as uncroppable")
    func depthUncroppable() {
        let info: [CFString: Any] = [kCGImageAuxiliaryDataInfoData: Data()]
        let frame = CGSize(width: 4, height: 3)
        let rectangle = CGRect(x: 0, y: 0, width: 3, height: 3)
        let result = PhotoAuxiliaryImage.crop(info, type: kCGImageAuxiliaryDataTypeDepth, to: rectangle, in: frame)
        #expect(throws: PhotoAuxiliaryImage.CropFailure.calibrated(kCGImageAuxiliaryDataTypeDepth as String)) {
            try result.get()
        }
    }

    @Test("An auxiliary image in a pixel format the cropper does not know is reported, not dropped")
    func unknownPixelFormat() {
        let description: [CFString: Any] = [
            "Width" as CFString: 2,
            "Height" as CFString: 2,
            "BytesPerRow" as CFString: 8,
            "PixelFormat" as CFString: UInt32(0x7834_3230)
        ]
        let info: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: Data(count: 16),
            kCGImageAuxiliaryDataInfoDataDescription: description
        ]
        let type = kCGImageAuxiliaryDataTypeHDRGainMap
        let frame = CGSize(width: 4, height: 4)
        let result = PhotoAuxiliaryImage.crop(info, type: type, to: CGRect(x: 0, y: 0, width: 2, height: 2), in: frame)
        let unknown = AuxiliaryPixels.Failure.unknownPixelFormat(type: type as String, pixelFormat: 0x7834_3230)
        let failure = PhotoAuxiliaryImage.CropFailure.unreadablePixels(unknown)
        #expect(throws: failure) {
            try result.get()
        }
    }

    @Test("Auxiliary pixels are cut row by row from the scaled region")
    func auxiliaryPixels() throws {
        // A 4 x 2 one-byte image with 8 bytes per row (padding of 4), values 0...15.
        let description: [CFString: Any] = [
            "Width" as CFString: 4,
            "Height" as CFString: 2,
            "BytesPerRow" as CFString: 8,
            "PixelFormat" as CFString: UInt32(0x4C30_3038)
        ]
        let info: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: Data(0..<16),
            kCGImageAuxiliaryDataInfoDataDescription: description
        ]
        // The photo is 8 x 4. Its middle 4 x 4 is the middle 2 x 2 of the auxiliary image.
        let rectangle = CGRect(x: 2, y: 0, width: 4, height: 4)
        let type = kCGImageAuxiliaryDataTypeHDRGainMap
        let frame = CGSize(width: 8, height: 4)
        let cropped = try PhotoAuxiliaryImage.crop(info, type: type, to: rectangle, in: frame).get()
        let data = try #require(cropped[kCGImageAuxiliaryDataInfoData] as? Data)
        #expect(Array(data) == [1, 2, 9, 10])
        let croppedDescription = try #require(cropped[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString: Any])
        #expect(croppedDescription["Width" as CFString] as? Int == 2)
        #expect(croppedDescription["Height" as CFString] as? Int == 2)
        #expect(croppedDescription["BytesPerRow" as CFString] as? Int == 2)
    }

    static let croppedRatios = [CameraFlowAspectRatio.sixteenByNine, .square]

    private func croppedFile(to aspectRatio: CameraFlowAspectRatio) throws -> Data {
        let photo = try DevicePhotoFixture.make()
        let outcome = try PhotoCaptureCropper.crop(photo, to: aspectRatio)
        guard case let .cropped(data) = outcome else {
            Issue.record("Expected a cropped photo, got \(outcome)")
            throw DevicePhotoFixture.FixtureError.unexpected
        }
        return data
    }
}
