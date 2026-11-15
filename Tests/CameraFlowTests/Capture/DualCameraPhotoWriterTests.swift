//
//  DualCameraPhotoWriterTests.swift
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

@Suite("Dual camera photo writer", .temporaryDirectory, .timeLimit(.minutes(1)))
struct DualCameraPhotoWriterTests {
    /// An upright main photo, the turns that bring the portrait viewfinder to it and the circle in the viewfinder.
    struct Shot: Sendable, CustomTestStringConvertible {
        let name: String
        let uprightSize: (width: Int, height: Int)
        let quarterTurns: Int

        /// The viewfinder in the proportions it has before the turn.
        var viewfinderHeightPerWidth: CGFloat {
            let isTurned = quarterTurns % 2 == 1
            let width = CGFloat(isTurned ? uprightSize.height : uprightSize.width)
            let height = CGFloat(isTurned ? uprightSize.width : uprightSize.height)
            return height / width
        }

        /// A square at the top trailing corner of the viewfinder, a third of its width.
        var region: CGRect {
            let width: CGFloat = 0.33
            let height = width / viewfinderHeightPerWidth
            return CGRect(x: 1 - 0.03 - width, y: 0.04, width: width, height: height)
        }

        var testDescription: String {
            name
        }
    }

    static let shots = [
        Shot(name: "4:3 portrait", uprightSize: (240, 320), quarterTurns: 0),
        Shot(name: "16:9 portrait", uprightSize: (180, 320), quarterTurns: 0),
        Shot(name: "1:1", uprightSize: (240, 240), quarterTurns: 0),
        Shot(name: "4:3 top of the phone to the left", uprightSize: (320, 240), quarterTurns: 3),
        Shot(name: "4:3 top of the phone to the right", uprightSize: (320, 240), quarterTurns: 1),
        Shot(name: "4:3 upside down", uprightSize: (240, 320), quarterTurns: 2)
    ]

    private let directory = CaptureTestSupport.makeFileStore().directory

    @Test(
        "The circle lands where the viewfinder showed it, as taken, over the upright photo at its full size",
        arguments: shots,
        OrientedPhotoFixture.orientations
    )
    func placement(shot: Shot, orientation: Int) async throws {
        let original = try DualCameraFixture.makeMainPhoto(
            uprightSize: shot.uprightSize,
            orientation: orientation,
            type: .jpeg,
            in: directory.appendingPathComponent("Originals")
        )
        let originalBytes = try Data(contentsOf: original)
        let frame = try DualCameraFixture.makeCircleFrame(
            uprightSize: (60, 80),
            orientation: orientation,
            viewfinderQuarterTurns: shot.quarterTurns
        )
        let circle = DualCameraFixture.circle(region: shot.region)
        let composition = DualCameraPhotoWriter.Composition(
            frame: frame,
            circle: circle,
            framedRegion: nil
        )
        let copy = try await DualCameraPhotoWriter.writeCopy(
            of: original,
            composition: composition,
            into: directory.appendingPathComponent("Copies")
        )
        let pixels = try PixelGrid(fileAt: copy)
        #expect(pixels.width == shot.uprightSize.width)
        #expect(pixels.height == shot.uprightSize.height)
        let square = DualCameraPlacement.circleRectangle(
            region: shot.region,
            quarterTurns: shot.quarterTurns,
            isViewfinderMirrored: false,
            framedRegion: nil,
            photoSize: CGSize(width: shot.uprightSize.width, height: shot.uprightSize.height)
        )
        try Self.expectCircle(in: pixels, square: square)
        #expect(try Data(contentsOf: original) == originalBytes)
        try FileManager.default.removeItem(at: directory)
    }

    @Test(
        "The copy keeps the EXIF, TIFF and GPS of the photo with the orientation written as upright",
        arguments: [UTType.jpeg, .heic]
    )
    func metadata(type: UTType) async throws {
        let shot = Self.shots[0]
        let original = try DualCameraFixture.makeMainPhoto(
            uprightSize: shot.uprightSize,
            orientation: 6,
            type: type,
            in: directory.appendingPathComponent("Originals")
        )
        let frame = try DualCameraFixture.makeCircleFrame(
            uprightSize: (60, 80),
            orientation: 6,
            viewfinderQuarterTurns: 0
        )
        let composition = DualCameraPhotoWriter.Composition(
            frame: frame,
            circle: DualCameraFixture.circle(region: shot.region),
            framedRegion: nil
        )
        let copy = try await DualCameraPhotoWriter.writeCopy(
            of: original,
            composition: composition,
            into: directory.appendingPathComponent("Copies")
        )
        #expect(copy.lastPathComponent == "main-dual-1.\(try #require(type.preferredFilenameExtension))")
        let source = try #require(CGImageSourceCreateWithURL(copy as CFURL, nil))
        #expect(CGImageSourceGetType(source) as String? == type.identifier)
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyOrientation] as? Int == 1)
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifLensModel] as? String == DualCameraFixture.lensModel)
        #expect(exif[kCGImagePropertyExifPixelXDimension] as? Int == shot.uprightSize.width)
        #expect(exif[kCGImagePropertyExifPixelYDimension] as? Int == shot.uprightSize.height)
        let tiff = try #require(properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any])
        #expect(tiff[kCGImagePropertyTIFFModel] as? String == "Dual fixture")
        #expect(tiff[kCGImagePropertyTIFFOrientation] as? Int == 1)
        let gps = try #require(properties[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        #expect(gps[kCGImagePropertyGPSLatitude] as? Double == DualCameraFixture.latitude)
        try FileManager.default.removeItem(at: directory)
    }

    @Test("A photo handed over whole gets the circle inside the region the viewfinder framed")
    func framedRegion() async throws {
        let original = try DualCameraFixture.makeMainPhoto(
            uprightSize: (240, 320),
            orientation: 1,
            type: .jpeg,
            in: directory.appendingPathComponent("Originals")
        )
        let frame = try DualCameraFixture.makeCircleFrame(
            uprightSize: (60, 80),
            orientation: 1,
            viewfinderQuarterTurns: 0
        )
        // A 16:9 viewfinder over the 4:3 photo: the middle three quarters of its width.
        let framed = CGRect(x: 0.125, y: 0, width: 0.75, height: 1)
        let region = CGRect(x: 0.6, y: 0.05, width: 0.33, height: 0.33 * 9 / 16)
        let composition = DualCameraPhotoWriter.Composition(
            frame: frame,
            circle: DualCameraFixture.circle(region: region),
            framedRegion: framed
        )
        let copy = try await DualCameraPhotoWriter.writeCopy(
            of: original,
            composition: composition,
            into: directory.appendingPathComponent("Copies")
        )
        let pixels = try PixelGrid(fileAt: copy)
        let side = 0.33 * 0.75 * 240
        let square = CGRect(x: (0.125 + 0.6 * 0.75) * 240, y: 0.05 * 320, width: side, height: side)
        try Self.expectCircle(in: pixels, square: square)
        try FileManager.default.removeItem(at: directory)
    }

    @Test(
        "A main photo the viewfinder showed mirrored takes the circle at the mirrored place, its frame as taken",
        arguments: [true, false]
    )
    func mirroring(isViewfinderMirrored: Bool) async throws {
        let original = try DualCameraFixture.makeMainPhoto(
            uprightSize: (240, 320),
            orientation: 6,
            type: .jpeg,
            in: directory.appendingPathComponent("Originals")
        )
        let frame = try DualCameraFixture.makeCircleFrame(
            uprightSize: (60, 80),
            orientation: 8,
            isViewfinderMirrored: isViewfinderMirrored,
            viewfinderQuarterTurns: 0
        )
        let region = Self.shots[0].region
        let composition = DualCameraPhotoWriter.Composition(
            frame: frame,
            circle: DualCameraFixture.circle(region: region),
            framedRegion: nil
        )
        let copy = try await DualCameraPhotoWriter.writeCopy(
            of: original,
            composition: composition,
            into: directory.appendingPathComponent("Copies")
        )
        let pixels = try PixelGrid(fileAt: copy)
        let square = DualCameraPlacement.circleRectangle(
            region: region,
            quarterTurns: 0,
            isViewfinderMirrored: isViewfinderMirrored,
            framedRegion: nil,
            photoSize: CGSize(width: 240, height: 320)
        )
        try Self.expectCircle(in: pixels, square: square)
        try FileManager.default.removeItem(at: directory)
    }

    /// The mark of the frame, in its top leading corner as taken, shows in the top leading quarter of the circle: the
    /// frame is never mirrored. The rest of the circle is the frame's colour and the corners of its square are the
    /// photo.
    private static func expectCircle(in pixels: PixelGrid, square: CGRect) throws {
        let radius = square.width / 2
        let offset = radius * 0.4
        func pixel(_ column: CGFloat, _ row: CGFloat) throws -> PixelGrid.Pixel {
            try pixels[Int(column.rounded(.down)), Int(row.rounded(.down))]
        }
        let mark = try pixel(square.midX - offset, square.midY - offset)
        let unmarked = try pixel(square.midX + offset, square.midY - offset)
        let lower = try pixel(square.midX, square.midY + offset)
        let corner = try pixel(square.minX + 2, square.minY + 2)
        let outside = try pixel(square.minX - 6, square.maxY + 6)
        #expect(mark.isClose(to: DualCameraFixture.markColor), "The mark is \(mark)")
        #expect(unmarked.isClose(to: DualCameraFixture.circleColor), "Beside the mark is \(unmarked)")
        #expect(lower.isClose(to: DualCameraFixture.circleColor), "Below the mark is \(lower)")
        #expect(corner.isClose(to: DualCameraFixture.mainColor), "The corner of the square is \(corner)")
        #expect(outside.isClose(to: DualCameraFixture.mainColor), "Outside the circle is \(outside)")
    }
}
