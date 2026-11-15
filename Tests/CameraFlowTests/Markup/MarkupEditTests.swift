//
//  MarkupEditTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import PaperKit
import PencilKit
import Testing
@testable import CameraFlow

/// The editing both canvases share: what a canvas shows when it takes its size, whether it changed, and the drawing
/// that comes out of it. The PencilKit cases read fixture drawings only: PencilKit stops the test process when it
/// makes or moves a stroke, so a PencilKit drawing is scaled on the PaperKit cases' path only.
@Suite("Editing a drawing on a canvas")
@MainActor
struct MarkupEditTests {
    private static let red = PixelGrid.Pixel(red: 255, green: 0, blue: 0)

    // MARK: - PencilKit

    @Test("A canvas opened without a drawing shows an empty one, and an empty canvas keeps none")
    func emptyPencilCanvas() async throws {
        let edit = try MarkupEdit<PKDrawing>(nil)
        let shown = edit.open(canvasSize: PencilStrokeFixture.canvasSize)
        #expect(shown.strokes.isEmpty)
        #expect(edit.changedDrawing(shown) == nil)
        #expect(edit.changedDrawing(PKDrawing()) == nil)
        #expect(try await edit.currentDrawing(PKDrawing()) == nil)
    }

    @Test("A drawing made on a canvas of the size the canvas takes opens as it was kept and comes back unchanged")
    func storedPencilDrawing() async throws {
        let stored = try PencilStrokeFixture.redInk()
        let edit = try MarkupEdit<PKDrawing>(stored)
        let shown = edit.open(canvasSize: stored.canvasSize)
        #expect(shown == (try stored.pencilDrawing()))
        #expect(edit.changedDrawing(shown) == nil)
        let current = try await edit.currentDrawing(shown)
        #expect(current?.identifier == stored.identifier)
    }

    @Test("Strokes on a canvas that opened empty are kept with the size the canvas took")
    func newPencilStrokes() async throws {
        let canvasSize = PencilStrokeFixture.portraitCanvasSize
        let edit = try MarkupEdit<PKDrawing>(nil)
        _ = edit.open(canvasSize: canvasSize)
        let strokes = try PencilStrokeFixture.verticalRedInk().pencilDrawing()
        #expect(edit.changedDrawing(strokes) == strokes)
        let current = try await edit.currentDrawing(strokes)
        let drawing = try #require(current)
        #expect(drawing.engine == .pencilKit)
        #expect(drawing.canvasSize == canvasSize)
        #expect(try drawing.pencilDrawing() == strokes)
    }

    @Test("Erasing the drawing changes the canvas and leaves no drawing to keep")
    func erasedPencilDrawing() async throws {
        let stored = try PencilStrokeFixture.redInk()
        let edit = try MarkupEdit<PKDrawing>(stored)
        _ = edit.open(canvasSize: stored.canvasSize)
        #expect(edit.changedDrawing(PKDrawing()) != nil)
        #expect(try await edit.currentDrawing(PKDrawing()) == nil)
    }

    @Test("Before the canvas takes its size it has no changes and keeps the drawing it was opened with")
    func unopenedCanvas() async throws {
        let stored = try PencilStrokeFixture.redInk()
        let edit = try MarkupEdit<PKDrawing>(stored)
        #expect(edit.isOpen == false)
        #expect(edit.changedDrawing(PKDrawing()) == nil)
        #expect(try await edit.currentDrawing(PKDrawing())?.identifier == stored.identifier)
        _ = edit.open(canvasSize: stored.canvasSize)
        #expect(edit.isOpen)
    }

    @Test("Data PencilKit cannot read is refused when the canvas is made")
    func undecodablePencilDrawing() throws {
        let canvasSize = PencilStrokeFixture.canvasSize
        let drawing = try MarkupDrawing(engine: .pencilKit, data: Data("scribble".utf8), canvasSize: canvasSize)
        let error = #expect(throws: MarkupFailure.self) {
            try MarkupEdit<PKDrawing>(drawing)
        }
        guard case .undecodableDrawing(.pencilKit, _) = error else {
            Issue.record("The failure is \(String(describing: error))")
            return
        }
    }

    // MARK: - PaperKit

    @Test("A PaperKit drawing made on a canvas of another size opens scaled to the canvas, over the same place")
    @available(iOS 26, macOS 26, *)
    func scaledPaperDrawing() async throws {
        let pencilDrawing = try PencilStrokeFixture.redInk()
        let stored = try await PaperMarkupFixture.drawing(of: pencilDrawing)
        let scale = 10
        let transform = CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))
        let canvasSize = stored.canvasSize.applying(transform)
        let edit = try MarkupEdit<PaperMarkup>(stored)
        let shown = edit.open(canvasSize: canvasSize)
        #expect(shown.bounds == CGRect(origin: .zero, size: canvasSize))
        #expect(edit.changedDrawing(shown) == nil)
        #expect(try await edit.currentDrawing(shown)?.identifier == stored.identifier)
        let data = try await shown.dataRepresentation()
        let scaled = try MarkupDrawing(engine: .paperKit, data: data, canvasSize: canvasSize)
        let storedInk = try await Self.inkAtStrokeMiddle(of: stored, scale: scale)
        let scaledInk = try await Self.inkAtStrokeMiddle(of: scaled, scale: scale)
        #expect(storedInk.isClose(to: Self.red), "The ink of the stored drawing is \(storedInk)")
        #expect(scaledInk.isClose(to: Self.red), "The ink of the scaled drawing is \(scaledInk)")
    }

    @Test("What is drawn on a PaperKit canvas that opened empty is kept with the size the canvas took")
    @available(iOS 26, macOS 26, *)
    func newPaperDrawing() async throws {
        let canvasSize = PencilStrokeFixture.canvasSize
        let edit = try MarkupEdit<PaperMarkup>(nil)
        let shown = edit.open(canvasSize: canvasSize)
        #expect(shown.isEmpty)
        #expect(shown.bounds == CGRect(origin: .zero, size: canvasSize))
        #expect(edit.changedDrawing(PaperMarkup(emptyCanvasOf: canvasSize)) == nil)
        #expect(try await edit.currentDrawing(shown) == nil)
        let strokes = try PencilStrokeFixture.redInk().pencilDrawing()
        var drawn = shown
        drawn.append(contentsOf: strokes)
        #expect(edit.changedDrawing(drawn) == drawn)
        let current = try await edit.currentDrawing(drawn)
        let drawing = try #require(current)
        #expect(drawing.engine == .paperKit)
        #expect(drawing.canvasSize == canvasSize)
        #expect(try drawing.paperMarkup().isEmpty == false)
    }

    @Test("A PaperKit canvas erased, or with no editor to read yet, keeps no drawing or the one it opened with")
    @available(iOS 26, macOS 26, *)
    func erasedPaperDrawing() async throws {
        let pencilDrawing = try PencilStrokeFixture.redInk()
        let stored = try await PaperMarkupFixture.drawing(of: pencilDrawing)
        let edit = try MarkupEdit<PaperMarkup>(stored)
        #expect(try await edit.currentDrawing(nil)?.identifier == stored.identifier)
        _ = edit.open(canvasSize: stored.canvasSize)
        #expect(edit.changedDrawing(nil) == nil)
        #expect(try await edit.currentDrawing(nil)?.identifier == stored.identifier)
        let erased = PaperMarkup(emptyCanvasOf: stored.canvasSize)
        #expect(edit.changedDrawing(erased) != nil)
        #expect(try await edit.currentDrawing(erased) == nil)
    }

    /// The pixel in the middle of the fixture's stroke, with the drawing rendered at `scale` times the fixture's
    /// canvas, whatever canvas the drawing was made on.
    private static func inkAtStrokeMiddle(of drawing: MarkupDrawing, scale: Int) async throws -> PixelGrid.Pixel {
        let transform = CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))
        let pixelSize = PencilStrokeFixture.canvasSize.applying(transform)
        let image = try await SystemMarkupRenderer().image(of: drawing, pixelSize: pixelSize)
        let middle = PencilStrokeFixture.strokeMiddle
        return try PixelGrid(image)[middle.column * scale, middle.row * scale]
    }
}
