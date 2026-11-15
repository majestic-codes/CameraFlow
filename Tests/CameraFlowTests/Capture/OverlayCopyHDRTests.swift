//
//  OverlayCopyHDRTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// The copy with a drawing or the second camera's circle of an HDR photo, read back with ImageIO: it keeps the gain
/// maps, the mattes, depth, the bit depth, the colour profile and every metadata key of the photo, as a copy without
/// an overlay does. Every test makes its photo with an ISO gain map, which the simulator cannot encode.
@Suite(
    "Overlay copy: HDR, auxiliary images, bit depth and metadata",
    .temporaryDirectory,
    .timeLimit(.minutes(1)),
    .needsDeviceImageIO(.isoGainMapEncoding)
)
struct OverlayCopyHDRTests {
    private static let overlayColor = PixelGrid.Pixel(red: 240, green: 30, blue: 220)
    /// The middle of the overlay in upright pixels of the photo.
    private static let overlayMiddle = (column: 32, row: 24)
    private static let tolerance = 12

    private let directory = CaptureTestSupport.makeFileStore().directory

    private var originals: URL {
        directory.appendingPathComponent("Originals", isDirectory: true)
    }

    private var copies: URL {
        directory.appendingPathComponent("Copies", isDirectory: true)
    }

    /// Fills the fixture's overlay rectangle, stretched over the size the writer asks for.
    private static func drawOverlay(in bitmap: CGContext, size: CGSize) {
        let horizontalScale = size.width / CGFloat(HDRPhotoFixture.uprightWidth)
        let verticalScale = size.height / CGFloat(HDRPhotoFixture.uprightHeight)
        let stretch = CGAffineTransform(scaleX: horizontalScale, y: verticalScale)
        let color = overlayColor
        bitmap.setFillColor(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: 1
        )
        bitmap.fill(OrientedPhotoFixture.overlayInBitmap.applying(stretch))
    }

    private func writeCopy(of original: URL, output: CameraFlowOutput = CameraFlowOutput()) async throws -> URL {
        try await OverlayPhotoWriter.writeCopy(
            of: original,
            into: copies,
            label: "markup",
            output: output
        ) { bitmap, size in
            Self.drawOverlay(in: bitmap, size: size)
        }
    }

    /// The pixel of an auxiliary image under a pixel of the upright photo, in a copy `scale` times smaller.
    private static func auxiliaryPixel(
        of type: CFString,
        under photoPixel: (column: Int, row: Int),
        scale: Int = 1
    ) -> (column: Int, row: Int) {
        let side = HDRPhotoFixture.scale(of: type) * scale
        return (photoPixel.column / side, photoPixel.row / side)
    }

    /// The level of an auxiliary image of a copy under a pixel of the upright photo.
    private static func level(
        of type: CFString,
        in copy: URL,
        under photoPixel: (column: Int, row: Int),
        scale: Int = 1
    ) throws -> UInt8 {
        let pixel = auxiliaryPixel(of: type, under: photoPixel, scale: scale)
        return try HDRPhotoFixture.level(of: type, in: copy, column: pixel.column, row: pixel.row)
    }

    private static func isClose(_ level: UInt8, to expected: UInt8) -> Bool {
        abs(Int(level) - Int(expected)) <= tolerance
    }

    // MARK: - Auxiliary images

    @Test(
        "The copy keeps every auxiliary image, turned upright with the photo",
        arguments: OrientedPhotoFixture.orientations
    )
    func auxiliaryImagesUpright(orientation: Int) async throws {
        let original = try HDRPhotoFixture.makeFile(orientation: orientation, type: .heic, in: originals)
        let copy = try await writeCopy(of: original)
        #expect(try HDRPhotoFixture.auxiliaryTypes(in: copy) == HDRPhotoFixture.auxiliaryTypes())
        for type in HDRPhotoFixture.auxiliaryTypes() {
            let pixels = try HDRPhotoFixture.auxiliaryPixels(of: type, in: copy)
            let size = HDRPhotoFixture.uprightSize(of: type)
            let comment = Comment("\(type) is \(pixels.width) x \(pixels.height)")
            #expect(pixels.width == size.width && pixels.height == size.height, comment)
        }
        for quarter in OrientedPhotoFixture.Quarter.allCases {
            for type in HDRPhotoFixture.levelTypes() {
                let level = try Self.level(of: type, in: copy, under: quarter.spot)
                let expected = HDRPhotoFixture.level(of: quarter, in: type)
                #expect(Self.isClose(level, to: expected), "\(type) is \(level) in \(quarter)")
            }
            let pixel = Self.auxiliaryPixel(of: kCGImageAuxiliaryDataTypeDisparity, under: quarter.spot)
            let disparity = try HDRPhotoFixture.disparity(in: copy, column: pixel.column, row: pixel.row)
            let expected = HDRPhotoFixture.disparity(of: quarter)
            expectClose(Double(disparity), Double(expected), tolerance: 0.02, "The disparity in \(quarter)")
        }
    }

    @Test("Under the overlay the gain maps are at no boost, around it as they were", arguments: [UTType.heic, .jpeg])
    func gainMapsUnderOverlay(type: UTType) async throws {
        let original = try HDRPhotoFixture.makeFile(orientation: 6, type: type, in: originals)
        let copy = try await writeCopy(of: original)
        try Self.expectNoBoostUnderOverlay(in: copy, gainMapTypes: PhotoGainMap.types, noBoostLevel: 0)
        for matte in HDRPhotoFixture.mattes {
            let level = try Self.level(of: matte, in: copy, under: Self.overlayMiddle)
            let expected = HDRPhotoFixture.level(of: .topLeft, in: matte)
            #expect(Self.isClose(level, to: expected), "\(matte) is \(level) under the overlay")
        }
    }

    @Test("An ISO gain map that darkens as well is at its own level of no boost under the overlay")
    @available(iOS 18, macOS 15, *)
    func isoGainMapUnderOverlay() async throws {
        let kind = HDRPhotoFixture.Kind.isoGainMapWithDarkening
        let original = try HDRPhotoFixture.makeFile(orientation: 3, type: .heic, kind: kind, in: originals)
        let copy = try await writeCopy(of: original)
        #expect(try HDRPhotoFixture.auxiliaryTypes(in: copy) == HDRPhotoFixture.auxiliaryTypes(kind))
        try Self.expectNoBoostUnderOverlay(
            in: copy,
            gainMapTypes: [kCGImageAuxiliaryDataTypeISOGainMap],
            noBoostLevel: HDRPhotoFixture.darkeningNoBoostLevel
        )
    }

    /// The gain maps of a copy are at the level of no boost under the overlay, and at full boost beside it.
    private static func expectNoBoostUnderOverlay(in copy: URL, gainMapTypes: [CFString], noBoostLevel: UInt8) throws {
        for gainMapType in gainMapTypes {
            let level = try level(of: gainMapType, in: copy, under: overlayMiddle)
            #expect(isClose(level, to: noBoostLevel), "\(gainMapType) is \(level) under the overlay")
            let beside = OrientedPhotoFixture.Quarter.topLeft.spot
            let besideLevel = try Self.level(of: gainMapType, in: copy, under: beside)
            #expect(besideLevel >= 240, "\(gainMapType) is \(besideLevel) beside the overlay")
        }
    }

    @Test("An HDR screen shows the overlay as it was drawn and the photo beside it brighter")
    func hdrRendering() async throws {
        let original = try HDRPhotoFixture.makeFile(orientation: 6, type: .heic, in: originals)
        let copy = try await writeCopy(of: original)
        let standard = try HDRRendering(fileAt: copy, decodeRequest: nil)
        let high = try HDRRendering(fileAt: copy, decodeRequest: kCGImageSourceDecodeToHDR)
        let overlay = Self.overlayMiddle
        let overlayBoost = high.luminance(overlay.column, overlay.row) / standard.luminance(overlay.column, overlay.row)
        expectClose(Double(overlayBoost), 1, tolerance: 0.1, "The boost of the overlay")
        let beside = OrientedPhotoFixture.Quarter.topLeft.spot
        let besideBoost = high.luminance(beside.column, beside.row) / standard.luminance(beside.column, beside.row)
        #expect(besideBoost >= 2, "The photo beside the overlay is boosted \(besideBoost) times")
        let overlayPixel = try PixelGrid(fileAt: copy)[overlay.column, overlay.row]
        #expect(overlayPixel.isClose(to: Self.overlayColor), "The overlay is \(overlayPixel)")
    }

    @Test("The copy with the circle keeps the photo's 10 bits and auxiliary images, at no boost under the circle")
    func dualCameraCopy() async throws {
        let original = try HDRPhotoFixture.makeFile(orientation: 6, type: .heic, bitsPerComponent: 16, in: originals)
        let frame = try DualCameraFixture.makeCircleFrame(
            uprightSize: (60, 80),
            orientation: 6,
            viewfinderQuarterTurns: 0
        )
        // A square a third of the viewfinder wide in its top right corner: in the top right quarter of the photo.
        let side = 0.33
        let photoSize = CGSize(width: HDRPhotoFixture.uprightWidth, height: HDRPhotoFixture.uprightHeight)
        let region = CGRect(x: 0.64, y: 0.04, width: side, height: side * photoSize.width / photoSize.height)
        let composition = DualCameraPhotoWriter.Composition(
            frame: frame,
            circle: DualCameraFixture.circle(region: region),
            framedRegion: nil
        )
        let copy = try await DualCameraPhotoWriter.writeCopy(of: original, composition: composition, into: copies)
        #expect(try ImageFile.properties(of: copy)[kCGImagePropertyDepth] as? Int == 10)
        #expect(try HDRPhotoFixture.auxiliaryTypes(in: copy) == HDRPhotoFixture.auxiliaryTypes())
        let square = DualCameraPlacement.circleRectangle(
            region: region,
            quarterTurns: 0,
            isViewfinderMirrored: frame.isViewfinderMirrored,
            framedRegion: nil,
            photoSize: photoSize
        )
        let circleMiddle = (column: Int(square.midX), row: Int(square.midY))
        for gainMapType in PhotoGainMap.types {
            let circleLevel = try Self.level(of: gainMapType, in: copy, under: circleMiddle)
            #expect(Self.isClose(circleLevel, to: 0), "\(gainMapType) is \(circleLevel) under the circle")
            for quarter in [OrientedPhotoFixture.Quarter.topLeft, .bottomLeft, .bottomRight] {
                let level = try Self.level(of: gainMapType, in: copy, under: quarter.spot)
                let expected = HDRPhotoFixture.level(of: quarter, in: gainMapType)
                #expect(Self.isClose(level, to: expected), "\(gainMapType) is \(level) in \(quarter)")
            }
        }
    }

    // MARK: - Bit depth, colour and metadata

    @Test("A photo of 10 bits is copied in 10, one of 8 in 8, both in Display P3", arguments: [(16, 10), (8, 8)])
    func bitDepth(bitsPerComponent: Int, depth: Int) async throws {
        let original = try HDRPhotoFixture.makeFile(
            orientation: 6,
            type: .heic,
            bitsPerComponent: bitsPerComponent,
            in: originals
        )
        let copy = try await writeCopy(of: original)
        let originalProperties = try ImageFile.properties(of: original)
        let properties = try ImageFile.properties(of: copy)
        #expect(originalProperties[kCGImagePropertyDepth] as? Int == depth)
        #expect(properties[kCGImagePropertyDepth] as? Int == depth)
        #expect(properties[kCGImagePropertyProfileName] as? String == "Display P3")
        let pixels = try PixelGrid(fileAt: copy)
        for quarter in OrientedPhotoFixture.Quarter.allCases {
            let pixel = try pixels[quarter.spot.column, quarter.spot.row]
            #expect(pixel.isClose(to: quarter.color), "\(quarter) is \(pixel)")
        }
    }

    /// A photo and the output its copy is written in.
    struct MetadataCase: Sendable, CustomTestStringConvertible {
        let name: String
        let type: UTType
        let kind: HDRPhotoFixture.Kind
        let format: CameraFlowOutputFormat

        var testDescription: String {
            name
        }
    }

    static let metadataCases = [
        MetadataCase(name: "HDR HEIC copied as it is", type: .heic, kind: .cameraHDR, format: .original),
        MetadataCase(name: "HDR HEIC copied as a JPEG", type: .heic, kind: .cameraHDR, format: .jpeg(quality: 0.8)),
        MetadataCase(name: "HDR JPEG copied as it is", type: .jpeg, kind: .cameraHDR, format: .original),
        MetadataCase(name: "HEIC copied as a JPEG", type: .heic, kind: .standardRange, format: .jpeg(quality: 0.8)),
        MetadataCase(name: "JPEG copied as it is", type: .jpeg, kind: .standardRange, format: .original)
    ]

    @Test("The copy keeps every EXIF, TIFF, GPS and maker key, the colour space and the XMP", arguments: metadataCases)
    func metadata(metadataCase: MetadataCase) async throws {
        let original = try HDRPhotoFixture.makeFile(
            orientation: 6,
            type: metadataCase.type,
            kind: metadataCase.kind,
            in: originals
        )
        var output = CameraFlowOutput()
        output.format = metadataCase.format
        let copy = try await writeCopy(of: original, output: output)
        let originalProperties = try ImageFile.properties(of: original)
        let originalExif = try #require(originalProperties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(originalExif[kCGImagePropertyExifColorSpace] as? Int == HDRPhotoFixture.colorSpaceTag)
        let properties = try ImageFile.properties(of: copy)
        let dictionaries = [
            kCGImagePropertyExifDictionary,
            kCGImagePropertyTIFFDictionary,
            kCGImagePropertyGPSDictionary,
            kCGImagePropertyMakerAppleDictionary
        ]
        for name in dictionaries {
            let originalKeys = Set(try #require(originalProperties[name] as? [String: Any]).keys)
            let lost = originalKeys.subtracting(try #require(properties[name] as? [String: Any]).keys)
            #expect(lost.isEmpty, "\(name) lost \(lost.sorted())")
        }
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifColorSpace] as? Int == HDRPhotoFixture.colorSpaceTag)
        #expect(exif[kCGImagePropertyExifLensModel] as? String == HDRPhotoFixture.lensModel)
        #expect(exif[kCGImagePropertyExifPixelXDimension] as? Int == HDRPhotoFixture.uprightWidth)
        #expect(properties[kCGImagePropertyOrientation] as? Int == 1)
        let source = try #require(CGImageSourceCreateWithURL(copy as CFURL, nil))
        let metadata = try #require(CGImageSourceCopyMetadataAtIndex(source, 0, nil))
        let label = CGImageMetadataCopyStringValueWithPath(metadata, nil, HDRPhotoFixture.xmpPath)
        #expect(label as String? == HDRPhotoFixture.xmpValue)
        #expect(try HDRPhotoFixture.auxiliaryTypes(in: copy) == HDRPhotoFixture.auxiliaryTypes(metadataCase.kind))
    }
}

extension OverlayCopyHDRTests {
    // MARK: - Outputs

    @Test("A scaled copy scales its gain maps and mattes with it and keeps disparity at its size")
    func scaledCopy() async throws {
        let original = try HDRPhotoFixture.makeFile(orientation: 8, type: .heic, in: originals)
        var output = CameraFlowOutput()
        output.size = .longSide(maximum: HDRPhotoFixture.uprightWidth / 2)
        let copy = try await writeCopy(of: original, output: output)
        let properties = try ImageFile.properties(of: copy)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == HDRPhotoFixture.uprightWidth / 2)
        for type in HDRPhotoFixture.levelTypes() {
            let pixels = try HDRPhotoFixture.auxiliaryPixels(of: type, in: copy)
            let size = HDRPhotoFixture.uprightSize(of: type)
            let comment = Comment("\(type) is \(pixels.width) x \(pixels.height)")
            #expect(pixels.width == size.width / 2 && pixels.height == size.height / 2, comment)
            let spot = OrientedPhotoFixture.Quarter.bottomRight.spot
            let level = try Self.level(of: type, in: copy, under: spot, scale: 2)
            let expected = HDRPhotoFixture.level(of: .bottomRight, in: type)
            #expect(Self.isClose(level, to: expected), "\(type) is \(level) at the bottom right")
        }
        let disparity = try HDRPhotoFixture.auxiliaryPixels(of: kCGImageAuxiliaryDataTypeDisparity, in: copy)
        let size = HDRPhotoFixture.uprightSize(of: kCGImageAuxiliaryDataTypeDisparity)
        #expect(disparity.width == size.width && disparity.height == size.height)
    }

    @Test("A copy without the metadata has no auxiliary images, and keeps its bit depth")
    func stripped() async throws {
        let original = try HDRPhotoFixture.makeFile(orientation: 6, type: .heic, bitsPerComponent: 16, in: originals)
        var output = CameraFlowOutput()
        output.metadata = .stripped
        let copy = try await writeCopy(of: original, output: output)
        #expect(try HDRPhotoFixture.auxiliaryTypes(in: copy).isEmpty)
        let properties = try ImageFile.properties(of: copy)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(properties[kCGImagePropertyDepth] as? Int == 10)
    }
}

/// The luminance a file shows, decoded as ImageIO is asked to, in linear extended Display P3.
private struct HDRRendering {
    private let values: [Float]
    private let width: Int

    init(fileAt url: URL, decodeRequest: CFString?) throws {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let options = decodeRequest.map { [kCGImageSourceDecodeRequest: $0] as CFDictionary }
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, options))
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3))
        let floatInfo = CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let context = try #require(
            CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 32,
                bytesPerRow: image.width * 16,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | floatInfo
            )
        )
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try #require(context.data)
        let floats = data.assumingMemoryBound(to: Float.self)
        values = Array(UnsafeBufferPointer(start: floats, count: image.width * image.height * 4))
        width = image.width
    }

    /// The mean of the red, green and blue of a pixel, counted from the top left.
    func luminance(_ column: Int, _ row: Int) -> Float {
        let offset = (row * width + column) * 4
        return (values[offset] + values[offset + 1] + values[offset + 2]) / 3
    }
}
