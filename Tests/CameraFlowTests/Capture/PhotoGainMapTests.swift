//
//  PhotoGainMapTests.swift
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

/// The gain map of an HDR photo: scaled for a smaller copy, and in a copy encoded again.
@Suite("Gain map of a copy", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoGainMapTests {
    private let type = kCGImageAuxiliaryDataTypeHDRGainMap

    /// A gain map of one byte per pixel whose rows are padded: every pixel of a row has the number of the row.
    private func makeGainMap(
        width: Int,
        height: Int,
        pixelFormat: OSType = kCVPixelFormatType_OneComponent8
    ) -> PhotoGainMap {
        let bytesPerRow = width + 3
        var pixels = Data()
        for row in 0..<height {
            pixels.append(Data(repeating: UInt8(row * 255 / (height - 1)), count: width))
            pixels.append(Data(repeating: 0xEE, count: bytesPerRow - width))
        }
        let description: [CFString: Any] = [
            "Width" as CFString: width,
            "Height" as CFString: height,
            "BytesPerRow" as CFString: bytesPerRow,
            "PixelFormat" as CFString: pixelFormat
        ]
        let info: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: pixels,
            kCGImageAuxiliaryDataInfoDataDescription: description,
            kCGImageAuxiliaryDataInfoMetadata: "kept as it is"
        ]
        return PhotoGainMap(type: type, info: info)
    }

    private func photo(of data: Data) throws -> ImageSourcePhoto {
        try ImageSourcePhoto(data: data)
    }

    // MARK: - Scaling

    @Test("A gain map scaled to a half has half the size, no padding, and its rows in their order")
    func scaledToHalf() throws {
        let scaled = try #require(makeGainMap(width: 8, height: 6).scaled(by: 0.5))
        let description = try #require(scaled.info[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString: Any])
        #expect(description["Width" as CFString] as? Int == 4)
        #expect(description["Height" as CFString] as? Int == 3)
        #expect(description["BytesPerRow" as CFString] as? Int == 4)
        #expect(description["PixelFormat" as CFString] as? UInt32 == kCVPixelFormatType_OneComponent8)
        let pixels = try #require(scaled.info[kCGImageAuxiliaryDataInfoData] as? Data)
        #expect(pixels.count == 12)
        let rows = stride(from: 0, to: 12, by: 4).map { Array(pixels[$0..<($0 + 4)]) }
        // Every row is flat, since the source rows are, and the padding never reaches a pixel.
        #expect(rows.allSatisfy { Set($0).count == 1 })
        let levels = rows.compactMap(\.first)
        #expect(levels == levels.sorted())
        #expect(try #require(levels.first) < 80)
        #expect(try #require(levels.last) > 175)
        #expect(scaled.type == type)
        #expect(scaled.info[kCGImageAuxiliaryDataInfoMetadata] as? String == "kept as it is")
    }

    @Test("A gain map never gets smaller than one pixel")
    func neverEmpty() throws {
        let scaled = try #require(makeGainMap(width: 8, height: 6).scaled(by: 0.01))
        let description = try #require(scaled.info[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString: Any])
        #expect(description["Width" as CFString] as? Int == 1)
        #expect(description["Height" as CFString] as? Int == 1)
        #expect((scaled.info[kCGImageAuxiliaryDataInfoData] as? Data)?.count == 1)
    }

    @Test("A copy of the same size takes the gain map as it is, whatever its pixel format")
    func unscaled() throws {
        let gainMap = makeGainMap(width: 8, height: 6, pixelFormat: kCVPixelFormatType_OneComponent16Half)
        let kept = try #require(gainMap.scaled(by: 1))
        let pixels = try #require(gainMap.info[kCGImageAuxiliaryDataInfoData] as? Data)
        #expect(kept.info[kCGImageAuxiliaryDataInfoData] as? Data == pixels)
    }

    @Test("A gain map in a pixel format of more than one byte is not scaled, and neither is one without a description")
    func unscalable() {
        let wide = makeGainMap(width: 8, height: 6, pixelFormat: kCVPixelFormatType_OneComponent16Half)
        #expect(wide.scaled(by: 0.5) == nil)
        let bare = PhotoGainMap(type: type, info: [kCGImageAuxiliaryDataInfoData: Data(count: 48)])
        #expect(bare.scaled(by: 0.5) == nil)
    }

    @Test("A gain map with fewer bytes than its description says is not scaled")
    func truncated() {
        var info = makeGainMap(width: 8, height: 6).info
        info[kCGImageAuxiliaryDataInfoData] = Data(count: 20)
        #expect(PhotoGainMap(type: type, info: info).scaled(by: 0.5) == nil)
    }

    // MARK: - The gain maps of a photo

    @Test("The device's photo has one gain map")
    func gainMapOfPhoto() throws {
        let deviceData = try DevicePhotoFixture.make()
        let devicePhoto = try photo(of: deviceData)
        #expect(PhotoGainMap.gainMaps(of: devicePhoto).map(\.type) == [type])
    }

    @Test("A photo without a gain map has none")
    func noGainMap() throws {
        let jpegData = try FlowTestSupport.makeJPEG()
        let jpeg = try photo(of: jpegData)
        #expect(PhotoGainMap.gainMaps(of: jpeg).isEmpty)
    }

    // MARK: - Copies

    @Test("A HEIC encoded again at its own size keeps the gain map at its size", arguments: [0.5, 0.9])
    func keptWhenEncodedAgain(quality: Double) throws {
        var output = CameraFlowOutput()
        output.format = .heic(quality: quality)
        let photo = try DevicePhotoFixture.make()
        let encoded = try #require(try PhotoOutputEncoder(output: output).encode(photo))
        let gainMap = try DevicePhotoFixture.gainMap(of: encoded.data)
        #expect(gainMap.width == DevicePhotoFixture.width / 2)
        #expect(gainMap.height == DevicePhotoFixture.height / 2)
        #expect(gainMap.hasVersionTag)
    }
}
