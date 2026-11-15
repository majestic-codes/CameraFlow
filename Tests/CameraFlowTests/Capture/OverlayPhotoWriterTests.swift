//
//  OverlayPhotoWriterTests.swift
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
@testable import CameraFlow

@Suite("Overlay photo writer", .temporaryDirectory, .timeLimit(.minutes(1)))
struct OverlayPhotoWriterTests {
    private static let overlayColor = PixelGrid.Pixel(red: 240, green: 30, blue: 220)
    private static let uprightSize = CGSize(
        width: OrientedPhotoFixture.uprightWidth,
        height: OrientedPhotoFixture.uprightHeight
    )

    /// A folder of its own for the originals and the copies of one test.
    private let directory = CaptureTestSupport.makeFileStore().directory

    private var originals: URL {
        directory.appendingPathComponent("Originals", isDirectory: true)
    }

    private var copies: URL {
        directory.appendingPathComponent("Copies", isDirectory: true)
    }

    @Test("The copy is the upright photo with the overlay in its place", arguments: OrientedPhotoFixture.orientations)
    func orientation(orientation: Int) async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: orientation, type: .jpeg, in: originals)
        let originalBytes = try Data(contentsOf: original)
        let copy = try await OverlayPhotoWriter.writeCopy(of: original, into: copies, label: "markup") { bitmap, size in
            #expect(size == Self.uprightSize)
            Self.drawOverlay(in: bitmap)
        }
        let properties = try ImageFile.properties(of: copy)
        #expect(properties[kCGImagePropertyOrientation] as? Int == 1)
        let pixels = try PixelGrid(fileAt: copy)
        #expect(pixels.width == OrientedPhotoFixture.uprightWidth)
        #expect(pixels.height == OrientedPhotoFixture.uprightHeight)
        for quarter in OrientedPhotoFixture.Quarter.allCases {
            let pixel = try pixels[quarter.spot.column, quarter.spot.row]
            #expect(pixel.isClose(to: quarter.color), "\(quarter) is \(pixel)")
        }
        let overlayPixel = try pixels[OrientedPhotoFixture.overlaySpot.column, OrientedPhotoFixture.overlaySpot.row]
        #expect(overlayPixel.isClose(to: Self.overlayColor), "The overlay is \(overlayPixel)")
        #expect(try Data(contentsOf: original) == originalBytes)
        try FileManager.default.removeItem(at: directory)
    }

    @Test("The copy keeps the EXIF, TIFF and GPS of the photo, for its upright pixels", arguments: [UTType.jpeg, .heic])
    func metadata(type: UTType) async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: 6, type: type, in: originals)
        let copy = try await OverlayPhotoWriter.writeCopy(of: original, into: copies, label: "markup") { _, _ in }
        let properties = try ImageFile.properties(of: copy)
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifLensModel] as? String == OrientedPhotoFixture.lensModel)
        #expect(exif[kCGImagePropertyExifDateTimeOriginal] as? String == OrientedPhotoFixture.captureDate)
        #expect(exif[kCGImagePropertyExifPixelXDimension] as? Int == OrientedPhotoFixture.uprightWidth)
        #expect(exif[kCGImagePropertyExifPixelYDimension] as? Int == OrientedPhotoFixture.uprightHeight)
        let tiff = try #require(properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any])
        #expect(tiff[kCGImagePropertyTIFFModel] as? String == "Fixture")
        #expect(tiff[kCGImagePropertyTIFFOrientation] as? Int == 1)
        let gps = try #require(properties[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        #expect(gps[kCGImagePropertyGPSLatitude] as? Double == OrientedPhotoFixture.latitude)
        #expect(gps[kCGImagePropertyGPSLongitudeRef] as? String == "E")
        try FileManager.default.removeItem(at: directory)
    }

    @Test("The copy of a device photo keeps every dictionary key, the XMP, its 10 bits and its gain map, upright")
    func devicePhoto() async throws {
        let original = try deviceFile(DevicePhotoFixture.make(bitsPerComponent: 16))
        let copy = try await OverlayPhotoWriter.writeCopy(of: original, into: copies, label: "markup") { _, _ in }
        let originalProperties = try ImageFile.properties(of: original)
        let properties = try ImageFile.properties(of: copy)
        for name in DevicePhotoFixture.dictionaryNames {
            let originalDictionary = try #require(originalProperties[name] as? [CFString: Any])
            let dictionary = try #require(properties[name] as? [CFString: Any])
            #expect(Set(originalDictionary.keys).isSubset(of: Set(dictionary.keys)), "\(name) lost keys")
        }
        // The fixture stores 256 x 192 with orientation 6, which is 192 x 256 upright.
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == DevicePhotoFixture.height)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == DevicePhotoFixture.width)
        #expect(properties[kCGImagePropertyOrientation] as? Int == 1)
        #expect(originalProperties[kCGImagePropertyDepth] as? Int == 10)
        #expect(properties[kCGImagePropertyDepth] as? Int == 10)
        let source = try #require(CGImageSourceCreateWithURL(copy as CFURL, nil))
        let metadata = try #require(CGImageSourceCopyMetadataAtIndex(source, 0, nil))
        let label = CGImageMetadataCopyStringValueWithPath(metadata, nil, DevicePhotoFixture.xmpPath)
        #expect(label as String? == DevicePhotoFixture.xmpValue)
        // The gain map is half the photo on each side, turned upright with it.
        let copyData = try Data(contentsOf: copy)
        let gainMap = try DevicePhotoFixture.gainMap(of: copyData)
        #expect(gainMap.width == DevicePhotoFixture.height / 2)
        #expect(gainMap.height == DevicePhotoFixture.width / 2)
        #expect(gainMap.hasVersionTag)
        try FileManager.default.removeItem(at: directory)
    }

    @Test("The copy of a camera file keeps the maker dictionary")
    func makerDictionary() async throws {
        let original = try deviceFile(DevicePhotoFixture.makeCameraFile())
        let copy = try await OverlayPhotoWriter.writeCopy(of: original, into: copies, label: "markup") { _, _ in }
        let originalProperties = try ImageFile.properties(of: original)
        let properties = try ImageFile.properties(of: copy)
        let originalMaker = try #require(originalProperties[kCGImagePropertyMakerAppleDictionary] as? [String: Any])
        let maker = try #require(properties[kCGImagePropertyMakerAppleDictionary] as? [String: Any])
        #expect(originalMaker.count >= 10)
        #expect(Set(maker.keys) == Set(originalMaker.keys))
        try FileManager.default.removeItem(at: directory)
    }

    @Test(
        "A JPEG, a HEIC, a PNG and a TIFF keep their type, and a photo of any other type becomes a HEIC",
        arguments: [
            (UTType.jpeg, UTType.jpeg),
            (.heic, .heic),
            (.png, .png),
            (.tiff, .tiff),
            (.heif, .heic),
            (.gif, .heic),
            (.webP, .heic),
            (.bmp, .heic),
            (.rawImage, .heic),
            (UTType("com.adobe.raw-image"), .heic),
            (nil, .heic)
        ] as [(UTType?, UTType)]
    )
    func copyType(photoType: UTType?, expected: UTType) {
        #expect(OverlayPhotoWriter.copyType(forPhotoType: photoType) == expected)
    }

    @Test("The file of the copy has the type and the extension of the photo", arguments: [UTType.heic, .png, .tiff])
    func keptFileType(type: UTType) async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: 3, type: type, in: originals)
        let copy = try await OverlayPhotoWriter.writeCopy(of: original, into: copies, label: "markup") { _, _ in }
        #expect(try ImageFile.contentType(of: copy) == type)
        #expect(copy.pathExtension == type.preferredFilenameExtension)
        #expect(try ImageFile.properties(of: copy)[kCGImagePropertyOrientation] as? Int == 1)
        try FileManager.default.removeItem(at: directory)
    }

    @Test("A photo of a type ImageIO writes and a copy does not keep becomes a HEIC", arguments: [UTType.gif, .bmp])
    func droppedFileType(type: UTType) async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: 1, type: type, in: originals)
        #expect(try ImageFile.contentType(of: original) == type)
        let copy = try await OverlayPhotoWriter.writeCopy(of: original, into: copies, label: "markup") { _, _ in }
        #expect(try ImageFile.contentType(of: copy) == .heic)
        #expect(copy.lastPathComponent == "photo-markup-1.heic")
        try FileManager.default.removeItem(at: directory)
    }

    @Test("A photo of a type ImageIO only reads is copied as a HEIC")
    func readOnlyFileType() async throws {
        let original = try radianceFile()
        #expect(try ImageFile.typeIdentifier(of: original) == "public.radiance")
        let copy = try await OverlayPhotoWriter.writeCopy(of: original, into: copies, label: "markup") { _, _ in }
        #expect(try ImageFile.contentType(of: copy) == .heic)
        #expect(copy.lastPathComponent == "photo-markup-1.heic")
        try FileManager.default.removeItem(at: directory)
    }

    @Test("Every copy gets the next free number, and a file with a taken name stays as it is")
    func freeName() async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: 1, type: .jpeg, in: originals)
        try FileManager.default.createDirectory(at: copies, withIntermediateDirectories: true)
        let taken = copies.appendingPathComponent("photo-markup-1.jpeg")
        let takenBytes = Data("not a copy".utf8)
        try takenBytes.write(to: taken)
        let second = try await OverlayPhotoWriter.writeCopy(of: original, into: copies, label: "markup") { _, _ in }
        let third = try await OverlayPhotoWriter.writeCopy(of: original, into: copies, label: "markup") { _, _ in }
        #expect(second.lastPathComponent == "photo-markup-2.jpeg")
        #expect(third.lastPathComponent == "photo-markup-3.jpeg")
        #expect(try Data(contentsOf: taken) == takenBytes)
        #expect(try ImageFile.contentType(of: second) == .jpeg)
        let names = try FileManager.default.contentsOfDirectory(atPath: copies.path).sorted()
        #expect(names == ["photo-markup-1.jpeg", "photo-markup-2.jpeg", "photo-markup-3.jpeg"])
        try FileManager.default.removeItem(at: directory)
    }

    @Test(
        "A file that is no image is reported as unreadable, and so is a missing one",
        arguments: UnreadablePhotoFile.allCases
    )
    func unreadable(file: UnreadablePhotoFile) async throws {
        try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
        let photo = try file.url(in: originals, fileExtension: "jpeg")
        await #expect(throws: OverlayCopyFailure.unreadablePhoto(photo)) {
            try await OverlayPhotoWriter.writeCopy(of: photo, into: copies, label: "markup") { _, _ in }
        }
        #expect(FileManager.default.fileExists(atPath: copies.path) == false)
        try FileManager.default.removeItem(at: directory)
    }

    @Test("An overlay that fails stops the copy, and nothing is written")
    func failingOverlay() async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: 1, type: .jpeg, in: originals)
        let failure = MarkupFailure.undecodableDrawing(.pencilKit, "test")
        await #expect(throws: failure) {
            try await OverlayPhotoWriter.writeCopy(
                of: original,
                into: copies,
                label: "markup"
            ) { _, _ in throw failure }
        }
        #expect(FileManager.default.fileExists(atPath: copies.path) == false)
        try FileManager.default.removeItem(at: directory)
    }

    @Test("A directory that cannot be made is reported")
    func unusableDirectory() async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: 1, type: .jpeg, in: originals)
        await #expect {
            try await OverlayPhotoWriter.writeCopy(of: original, into: original, label: "markup") { _, _ in }
        } throws: { error in
            guard case .cannotStore = error as? OverlayCopyFailure else { return false }
            return true
        }
        try FileManager.default.removeItem(at: directory)
    }

    private static func drawOverlay(in bitmap: CGContext) {
        let color = overlayColor
        bitmap.setFillColor(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: 1
        )
        bitmap.fill(OrientedPhotoFixture.overlayInBitmap)
    }

    private func deviceFile(_ data: Data) throws -> URL {
        try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
        let url = originals.appendingPathComponent("device.heic")
        try data.write(to: url)
        return url
    }

    /// A 2 x 2 Radiance picture, a type ImageIO reads and does not write: a text header, then four bytes a pixel.
    private func radianceFile() throws -> URL {
        try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
        let url = originals.appendingPathComponent("photo.hdr")
        var data = Data("#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y 2 +X 2\n".utf8)
        for _ in 0..<4 {
            data.append(contentsOf: [128, 64, 32, 128])
        }
        try data.write(to: url)
        return url
    }
}

extension OverlayPhotoWriterTests {
    // MARK: - Clear parts

    private static let transparentPhotoColor = PixelGrid.Pixel(red: 30, green: 160, blue: 90)

    /// A photo of the fixture's upright size, clear but for an opaque square in its middle.
    private static func transparentFile(type: UTType, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let width = OrientedPhotoFixture.uprightWidth
        let height = OrientedPhotoFixture.uprightHeight
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
        let color = transparentPhotoColor
        context.setFillColor(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: 1
        )
        context.fill(CGRect(x: width / 2 - 16, y: height / 2 - 16, width: 32, height: 32))
        let image = try #require(context.makeImage())
        let fileExtension = try #require(type.preferredFilenameExtension)
        let url = directory.appendingPathComponent("clear").appendingPathExtension(fileExtension)
        let typeIdentifier = type.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, typeIdentifier, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return url
    }

    @Test(
        "A photo with clear parts keeps them where the copy can hold them, and is flattened onto white in a JPEG",
        arguments: [
            (UTType.png, CameraFlowOutputFormat.original, true),
            (.png, .heic(quality: 0.8), true),
            (.png, .jpeg(quality: 0.8), false)
        ]
    )
    func transparency(type: UTType, format: CameraFlowOutputFormat, keepsClearParts: Bool) async throws {
        let original = try Self.transparentFile(type: type, in: originals)
        var output = CameraFlowOutput()
        output.format = format
        let copy = try await OverlayPhotoWriter.writeCopy(
            of: original,
            into: copies,
            label: "markup",
            output: output
        ) { bitmap, _ in
            Self.drawOverlay(in: bitmap)
        }
        let pixels = try PixelGrid(fileAt: copy)
        let corner = try pixels[2, 2]
        let middle = try pixels[OrientedPhotoFixture.uprightWidth / 2, OrientedPhotoFixture.uprightHeight / 2]
        let overlay = try pixels[OrientedPhotoFixture.overlaySpot.column, OrientedPhotoFixture.overlaySpot.row]
        if keepsClearParts {
            #expect(corner == .clear, "The corner is \(corner)")
        } else {
            #expect(corner.isClose(to: PixelGrid.Pixel(red: 255, green: 255, blue: 255)), "The corner is \(corner)")
        }
        #expect(middle.isClose(to: Self.transparentPhotoColor), "The middle is \(middle)")
        #expect(overlay.isClose(to: Self.overlayColor), "The overlay is \(overlay)")
        try FileManager.default.removeItem(at: directory)
    }
}
