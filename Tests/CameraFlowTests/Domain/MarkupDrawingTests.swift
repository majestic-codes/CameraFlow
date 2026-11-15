//
//  MarkupDrawingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@Suite("Stored drawing")
struct MarkupDrawingTests {
    private static let data = Data("strokes".utf8)

    @Test("A drawing keeps its engine, its data and the size of its canvas")
    func values() throws {
        let canvasSize = CGSize(width: 402, height: 536)
        let drawing = try MarkupDrawing(engine: .paperKit, data: Self.data, canvasSize: canvasSize)
        #expect(drawing.engine == .paperKit)
        #expect(drawing.data == Self.data)
        #expect(drawing.canvasSize == canvasSize)
        #expect(drawing == (try MarkupDrawing(engine: .paperKit, data: Self.data, canvasSize: canvasSize)))
        #expect(drawing != (try MarkupDrawing(engine: .pencilKit, data: Self.data, canvasSize: canvasSize)))
    }

    @Test("A drawing is told from another made apart by its identifier, and a copy keeps it")
    func identifier() throws {
        let canvasSize = CGSize(width: 402, height: 536)
        let drawing = try MarkupDrawing(engine: .paperKit, data: Self.data, canvasSize: canvasSize)
        let madeApart = try MarkupDrawing(engine: .paperKit, data: Self.data, canvasSize: canvasSize)
        let copy = drawing
        #expect(copy.identifier == drawing.identifier)
        #expect(madeApart.identifier != drawing.identifier)
    }

    @Test(
        "A canvas without an area holds no drawing",
        arguments: [
            CGSize.zero,
            CGSize(width: 402, height: 0),
            CGSize(width: 0, height: 536),
            CGSize(width: -402, height: 536)
        ]
    )
    func emptyCanvas(canvasSize: CGSize) {
        #expect(throws: MarkupFailure.emptyCanvas(canvasSize)) {
            try MarkupDrawing(engine: .pencilKit, data: Self.data, canvasSize: canvasSize)
        }
    }

    @Test("A place on the canvas goes to the same fraction of a canvas of another size")
    func scaling() throws {
        let canvasSize = CGSize(width: 400, height: 300)
        let drawing = try MarkupDrawing(engine: .pencilKit, data: Self.data, canvasSize: canvasSize)
        let scaling = drawing.scaling(toCanvasOf: CGSize(width: 4000, height: 3000))
        #expect(CGPoint(x: 100, y: 75).applying(scaling) == CGPoint(x: 1000, y: 750))
        #expect(CGPoint(x: 400, y: 300).applying(scaling) == CGPoint(x: 4000, y: 3000))
        #expect(drawing.scaling(toCanvasOf: drawing.canvasSize) == .identity)
        let stretching = drawing.scaling(toCanvasOf: CGSize(width: 200, height: 600))
        #expect(CGPoint(x: 100, y: 75).applying(stretching) == CGPoint(x: 50, y: 150))
    }
}
