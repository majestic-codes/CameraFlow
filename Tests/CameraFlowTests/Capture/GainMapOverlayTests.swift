//
//  GainMapOverlayTests.swift
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
@testable import CameraFlow

/// A gain map under an overlay: the level that means no boost, and each pixel brought to it as far as the overlay
/// covers it.
@Suite("Gain map under an overlay")
struct GainMapOverlayTests {

    /// A gain map of 4 x 2 pixels, all at `level`, with a byte of padding a row.
    private func uniformInfo(level: UInt8, pixelFormat: OSType = kCVPixelFormatType_OneComponent8) -> [CFString: Any] {
        var pixels = Data()
        for _ in 0..<2 {
            pixels.append(Data(repeating: level, count: 4))
            pixels.append(0xEE)
        }
        let description: [CFString: Any] = [
            "Width" as CFString: 4,
            "Height" as CFString: 2,
            "BytesPerRow" as CFString: 5,
            "PixelFormat" as CFString: pixelFormat
        ]
        return [
            kCGImageAuxiliaryDataInfoData: pixels,
            kCGImageAuxiliaryDataInfoDataDescription: description
        ]
    }

    /// Covers the left half of a bitmap and half covers its right half.
    private static func drawHalfAndFullCoverage(in bitmap: CGContext, size: CGSize) {
        let half = size.width / 2
        bitmap.setFillColor(gray: 0, alpha: 1)
        bitmap.fill(CGRect(x: 0, y: 0, width: half, height: size.height))
        bitmap.setFillColor(gray: 0, alpha: 0.5)
        bitmap.fill(CGRect(x: half, y: 0, width: size.width - half, height: size.height))
    }

    private func levels(of gainMap: PhotoGainMap) throws -> [UInt8] {
        let pixels = try AuxiliaryPixels(info: gainMap.info, type: gainMap.type)
        #expect(pixels.width == 4 && pixels.height == 2)
        return (0..<2).flatMap { row in
            (0..<4).map { column in pixels.data[pixels.data.startIndex + row * pixels.bytesPerRow + column] }
        }
    }

    @Test("Apple's gain map boosts by its level, so 0 is no boost")
    func appleNoBoost() {
        let gainMap = PhotoGainMap(type: kCGImageAuxiliaryDataTypeHDRGainMap, info: [:])
        #expect(gainMap.noBoostLevel() == .success(0))
    }

    @Test(
        "The ISO gain map has no boost at the gain of 0 stops in its range, raised to its gamma",
        .needsDeviceImageIO(.isoGainMapEncoding),
        arguments: [
            (0.0, 3.0, 1.0, UInt8(0)),
            (-1, 2, 1, 85),
            (-1, 2, 2, 28),
            (1, 3, 1, 0),
            (-2, -1, 1, 255),
            (2, 2, 1, 0)
        ]
    )
    @available(iOS 18, macOS 15, *)
    func isoNoBoost(minimum: Double, maximum: Double, gamma: Double, level: UInt8) throws {
        let info = try HDRPhotoFixture.isoGainMapInfo(minimum: minimum, maximum: maximum, gamma: gamma)
        let gainMap = PhotoGainMap(type: kCGImageAuxiliaryDataTypeISOGainMap, info: info)
        #expect(gainMap.noBoostLevel() == .success(level))
    }

    @Test(
        "An ISO gain map without metadata, or with a range or a gamma that make no gain, has no known level",
        .needsDeviceImageIO(.isoGainMapEncoding)
    )
    @available(iOS 18, macOS 15, *)
    func isoUnknownNoBoost() throws {
        let type = kCGImageAuxiliaryDataTypeISOGainMap
        var bare = try HDRPhotoFixture.isoGainMapInfo(minimum: 0, maximum: 3, gamma: 1)
        bare[kCGImageAuxiliaryDataInfoMetadata] = nil
        let flat = try HDRPhotoFixture.isoGainMapInfo(minimum: 0, maximum: 3, gamma: 0)
        let reversed = try HDRPhotoFixture.isoGainMapInfo(minimum: 3, maximum: 0, gamma: 1)
        for info in [bare, flat, reversed] {
            let result = PhotoGainMap(type: type, info: info).noBoostLevel()
            #expect(throws: PhotoGainMap.OverlayFailure.self) {
                try result.get()
            }
        }
    }

    @Test("Another auxiliary image is no gain map, and a gain map of more than one byte a pixel cannot go under one")
    func unusableGainMaps() {
        let matte = PhotoGainMap(type: kCGImageAuxiliaryDataTypePortraitEffectsMatte, info: uniformInfo(level: 9))
        #expect(throws: PhotoGainMap.OverlayFailure.self) {
            try matte.underOverlay().get()
        }
        let wideInfo = uniformInfo(level: 9, pixelFormat: kCVPixelFormatType_OneComponent16Half)
        let wide = PhotoGainMap(type: kCGImageAuxiliaryDataTypeHDRGainMap, info: wideInfo)
        #expect(throws: PhotoGainMap.OverlayFailure.self) {
            try wide.underOverlay().get()
        }
        let bareInfo: [CFString: Any] = [kCGImageAuxiliaryDataInfoData: Data()]
        let bare = PhotoGainMap(type: kCGImageAuxiliaryDataTypeHDRGainMap, info: bareInfo)
        #expect(throws: PhotoGainMap.OverlayFailure.self) {
            try bare.underOverlay().get()
        }
    }

    @Test("Each pixel goes to no boost as far as the overlay covers it, drawn at the size of the gain map")
    func neutralized() async throws {
        let gainMap = PhotoGainMap(type: kCGImageAuxiliaryDataTypeHDRGainMap, info: uniformInfo(level: 200))
        let underOverlay = try gainMap.underOverlay().get()
        var sizes: [CGSize] = []
        var coverages = OverlayCoverages()
        let neutralized = try await underOverlay.neutralized(under: &coverages) { bitmap, size in
            sizes.append(size)
            Self.drawHalfAndFullCoverage(in: bitmap, size: size)
        }
        #expect(sizes == [CGSize(width: 4, height: 2)])
        let levels = try levels(of: neutralized)
        for row in 0..<2 {
            #expect(levels[row * 4] == 0 && levels[row * 4 + 1] == 0, "The covered half is \(levels)")
            #expect((99...101).contains(levels[row * 4 + 2]) && (99...101).contains(levels[row * 4 + 3]), "\(levels)")
        }
        #expect(neutralized.type == kCGImageAuxiliaryDataTypeHDRGainMap)
    }

    @Test("An ISO gain map goes to its own level of no boost", .needsDeviceImageIO(.isoGainMapEncoding))
    @available(iOS 18, macOS 15, *)
    func isoNeutralized() async throws {
        var info = try HDRPhotoFixture.isoGainMapInfo(minimum: -1, maximum: 2, gamma: 1)
        for (key, value) in uniformInfo(level: 200) {
            info[key] = value
        }
        let gainMap = PhotoGainMap(type: kCGImageAuxiliaryDataTypeISOGainMap, info: info)
        var coverages = OverlayCoverages()
        let neutralized = try await gainMap.underOverlay().get().neutralized(under: &coverages) { bitmap, size in
            Self.drawHalfAndFullCoverage(in: bitmap, size: size)
        }
        let levels = try levels(of: neutralized)
        #expect(levels[0] == 85 && levels[4] == 85, "The covered half is \(levels)")
        #expect((141...143).contains(levels[3]), "The half covered half is \(levels)")
        #expect(neutralized.info[kCGImageAuxiliaryDataInfoColorSpace] != nil)
    }

    @Test("The overlay is drawn once for each size of gain map, however many gain maps have it")
    func coverageOncePerSize() async throws {
        var coverages = OverlayCoverages()
        var sizes: [CGSize] = []
        for (width, height) in [(4, 2), (4, 2), (8, 4), (4, 2)] {
            let levels = try await coverages.levels(width: width, height: height) { bitmap, size in
                sizes.append(size)
                Self.drawHalfAndFullCoverage(in: bitmap, size: size)
            }
            #expect(levels.count == width * height)
            #expect(levels.first == 255 && levels.last != 255, "\(levels)")
        }
        #expect(sizes == [CGSize(width: 4, height: 2), CGSize(width: 8, height: 4)])
    }

    @Test("An overlay that fails stops the gain map with its own error")
    func failingOverlay() async throws {
        let gainMap = PhotoGainMap(type: kCGImageAuxiliaryDataTypeHDRGainMap, info: uniformInfo(level: 200))
        let failure = MarkupFailure.undecodableDrawing(.pencilKit, "test")
        await #expect(throws: failure) {
            var coverages = OverlayCoverages()
            _ = try await gainMap.underOverlay().get().neutralized(under: &coverages) { _, _ in throw failure }
        }
    }
}
