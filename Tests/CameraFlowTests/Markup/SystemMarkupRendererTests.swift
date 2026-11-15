//
//  SystemMarkupRendererTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@Suite("System markup renderer", .temporaryDirectory, .timeLimit(.minutes(1)))
struct SystemMarkupRendererTests {
    private static let canvasSize = PencilStrokeFixture.canvasSize
    private static let strokeMiddle = PencilStrokeFixture.strokeMiddle
    private static let red = PixelGrid.Pixel(red: 255, green: 0, blue: 0)
    private static let white = PixelGrid.Pixel(red: 255, green: 255, blue: 255)
    private static let scales = [1, 4, 10]

    private let renderer = SystemMarkupRenderer()

    @Test("A PencilKit drawing is stretched over the size asked for, clear around the ink", arguments: scales)
    func pencilScale(scale: Int) async throws {
        let drawing = try PencilStrokeFixture.redInk()
        try await expectRedStroke(of: drawing, scale: scale)
    }

    @Test("A PaperKit drawing is stretched over the size asked for, clear around the ink", arguments: scales)
    @available(iOS 26, macOS 26, *)
    func paperScale(scale: Int) async throws {
        let pencilDrawing = try PencilStrokeFixture.redInk()
        let drawing = try await PaperMarkupFixture.drawing(of: pencilDrawing)
        try await expectRedStroke(of: drawing, scale: scale)
    }

    @Test("A PencilKit stroke that lies across two bands of the picture is painted whole")
    func pencilBands() async throws {
        // The stroke covers the rows from 4 to 8 points, which this scale puts on both sides of the pixel row 512.
        let scale = 85
        let transform = CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))
        let drawing = try PencilStrokeFixture.redInk()
        let image = try await renderer.image(of: drawing, pixelSize: Self.canvasSize.applying(transform))
        let pixels = try PixelGrid(image)
        let inkColumn = Self.strokeMiddle.column * scale
        for row in 500...524 {
            let ink = try pixels[inkColumn, row]
            #expect(ink.isClose(to: Self.red), "Row \(row) is \(ink)")
        }
        #expect(try pixels[inkColumn, 2 * scale] == .clear)
        #expect(try pixels[inkColumn, 10 * scale] == .clear)
    }

    @Test("A PencilKit stroke down a 393 x 524 canvas painted at 3024 x 4032 has ink on every row, across the bands")
    func pencilBandSeams() async throws {
        let pixelSize = CGSize(width: 3024, height: 4032)
        let drawing = try PencilStrokeFixture.verticalRedInk()
        let image = try await renderer.image(of: drawing, pixelSize: pixelSize)
        let pixels = try PixelGrid(image)
        let pixelsPerPoint = pixelSize.width / PencilStrokeFixture.portraitCanvasSize.width
        let column = Int(PencilStrokeFixture.verticalStrokeMiddle * pixelsPerPoint)
        let gaps = try (0..<pixels.height).filter { row in try pixels[column, row].isClose(to: Self.red) == false }
        #expect(gaps.isEmpty, "The stroke has no ink on the rows \(gaps.prefix(12))")
    }

    @Test("PencilKit ink has the colour the dark canvas shows: black ink is drawn white")
    func pencilDarkAppearance() async throws {
        let drawing = try PencilStrokeFixture.blackInk()
        try await expectWhiteStroke(of: drawing)
    }

    @Test("PaperKit ink has the colour the dark canvas shows: black ink is drawn white")
    @available(iOS 26, macOS 26, *)
    func paperDarkAppearance() async throws {
        let pencilDrawing = try PencilStrokeFixture.blackInk()
        let drawing = try await PaperMarkupFixture.drawing(of: pencilDrawing)
        try await expectWhiteStroke(of: drawing)
    }

    @Test("The copy has the drawing over the upright photo at its full size")
    func copy() async throws {
        let directory = CaptureTestSupport.makeFileStore().directory
        let original = try OrientedPhotoFixture.makeFile(orientation: 6, type: .jpeg, in: directory)
        let drawing = try PencilStrokeFixture.blackInk()
        let copy = try await renderer.writeCopy(
            of: original,
            with: drawing,
            output: CameraFlowOutput(),
            into: directory
        )
        #expect(copy.lastPathComponent == "photo-markup-1.jpeg")
        let pixels = try PixelGrid(fileAt: copy)
        try #require(pixels.width == OrientedPhotoFixture.uprightWidth)
        try #require(pixels.height == OrientedPhotoFixture.uprightHeight)
        let ink = try pixels[OrientedPhotoFixture.overlaySpot.column, OrientedPhotoFixture.overlaySpot.row]
        #expect(ink.isClose(to: Self.white), "The ink is \(ink)")
        for quarter in OrientedPhotoFixture.Quarter.allCases {
            let pixel = try pixels[quarter.spot.column, quarter.spot.row]
            #expect(pixel.isClose(to: quarter.color), "\(quarter) is \(pixel)")
        }
        try FileManager.default.removeItem(at: directory)
    }

    @Test("PencilKit data that is no drawing is reported, for the picture and for the copy")
    func undecodablePencilDrawing() async throws {
        let drawing = try MarkupDrawing(engine: .pencilKit, data: Data("scribble".utf8), canvasSize: Self.canvasSize)
        let directory = CaptureTestSupport.makeFileStore().directory
        let original = try OrientedPhotoFixture.makeFile(orientation: 1, type: .jpeg, in: directory)
        let pictureError = await #expect(throws: MarkupFailure.self) {
            try await renderer.image(of: drawing, pixelSize: Self.canvasSize)
        }
        #expect(Self.isUndecodable(pictureError, engine: .pencilKit), "\(String(describing: pictureError))")
        let copyError = await #expect(throws: MarkupFailure.self) {
            try await renderer.writeCopy(of: original, with: drawing, output: CameraFlowOutput(), into: directory)
        }
        #expect(Self.isUndecodable(copyError, engine: .pencilKit), "\(String(describing: copyError))")
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == [original.lastPathComponent])
        try FileManager.default.removeItem(at: directory)
    }

    @Test("A copy of a photo that cannot be read is reported as the markup's failure")
    func unreadablePhoto() async throws {
        let directory = CaptureTestSupport.makeFileStore().directory
        let missing = directory.appendingPathComponent("missing.heic")
        let drawing = try PencilStrokeFixture.redInk()
        await #expect(throws: MarkupFailure.unreadablePhoto(missing)) {
            try await renderer.writeCopy(
                of: missing,
                with: drawing,
                output: CameraFlowOutput(),
                into: directory
            )
        }
    }

    @Test("PaperKit data that is no drawing is reported, and so is a system without PaperKit")
    func undecodablePaperDrawing() async throws {
        let drawing = try MarkupDrawing(engine: .paperKit, data: Data("scribble".utf8), canvasSize: Self.canvasSize)
        let error = await #expect(throws: MarkupFailure.self) {
            try await renderer.image(of: drawing, pixelSize: Self.canvasSize)
        }
        if #available(iOS 26, macOS 26, *) {
            #expect(Self.isUndecodable(error, engine: .paperKit), "\(String(describing: error))")
        } else {
            #expect(error == .engineUnavailable(.paperKit))
        }
    }

    @Test("A picture without pixels is refused", arguments: [CGSize.zero, CGSize(width: 10, height: 0.2)])
    func emptyPicture(pixelSize: CGSize) async throws {
        let drawing = try PencilStrokeFixture.redInk()
        let failure = MarkupFailure.cannotCreateBitmap(width: Int(pixelSize.width), height: 0)
        await #expect(throws: failure) {
            try await renderer.image(of: drawing, pixelSize: pixelSize)
        }
    }

    /// Renders the drawing at a multiple of its canvas and looks for the red stroke where that multiple puts it.
    private func expectRedStroke(of drawing: MarkupDrawing, scale: Int) async throws {
        let transform = CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))
        let image = try await renderer.image(of: drawing, pixelSize: Self.canvasSize.applying(transform))
        let pixels = try PixelGrid(image)
        try #require(pixels.width == Int(Self.canvasSize.width) * scale)
        try #require(pixels.height == Int(Self.canvasSize.height) * scale)
        let inkColumn = Self.strokeMiddle.column * scale
        let inkRow = Self.strokeMiddle.row * scale
        let ink = try pixels[inkColumn, inkRow]
        #expect(ink.isClose(to: Self.red), "The ink is \(ink)")
        // The stroke is four points wide, so four points above and below its middle are clear.
        #expect(try pixels[inkColumn, inkRow - 4 * scale] == .clear)
        #expect(try pixels[inkColumn, inkRow + 4 * scale] == .clear)
        // The same spot mirrored to the right, to the bottom and to both is clear.
        let mirroredColumn = pixels.width - 1 - inkColumn
        let mirroredRow = pixels.height - 1 - inkRow
        #expect(try pixels[mirroredColumn, inkRow] == .clear)
        #expect(try pixels[inkColumn, mirroredRow] == .clear)
        #expect(try pixels[mirroredColumn, mirroredRow] == .clear)
    }

    private func expectWhiteStroke(of drawing: MarkupDrawing) async throws {
        let image = try await renderer.image(of: drawing, pixelSize: Self.canvasSize)
        let ink = try PixelGrid(image)[Self.strokeMiddle.column, Self.strokeMiddle.row]
        #expect(ink.isClose(to: Self.white), "The ink is \(ink)")
    }

    private static func isUndecodable(_ error: MarkupFailure?, engine: MarkupEngine) -> Bool {
        guard case .undecodableDrawing(engine, _) = error else { return false }
        return true
    }
}
