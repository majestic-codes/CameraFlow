//
//  FlowGlyphTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

/// The outlines against the paths of the approved mock-up (`cross`, `check`, `libraryRound`, `plusTile`, `strip` and
/// `ICON` in `mock.js`).
@Suite("Flow glyphs")
struct FlowGlyphTests {

    @Test(
        "An outline spans what the mock-up draws around the centre of its button",
        arguments: [
            (FlowGlyph.cross, CGRect(x: -6.5, y: -6.5, width: 13, height: 13)),
            (.checkmark, CGRect(x: -7.5, y: -5.5, width: 15, height: 11)),
            (.library, CGRect(x: -10, y: -10, width: 22, height: 16)),
            (.trash, CGRect(x: -7.5, y: -8, width: 15, height: 16)),
            (.plus, CGRect(x: -9, y: -9, width: 18, height: 18)),
            (.undo, CGRect(x: -6, y: -6.5, width: 13, height: 12.5)),
            (.redo, CGRect(x: -7, y: -6.5, width: 13, height: 12.5))
        ]
    )
    func bounds(glyph: FlowGlyph, expected: CGRect) {
        expectClose(glyph.outline.boundingBoxOfPath, expected)
    }

    @Test("The cross and the check mark are centred on their button")
    func centred() {
        #expect(FlowGlyph.cross.outline.boundingBoxOfPath.midX == 0)
        #expect(FlowGlyph.cross.outline.boundingBoxOfPath.midY == 0)
        #expect(FlowGlyph.checkmark.outline.boundingBoxOfPath.midX == 0)
        #expect(FlowGlyph.checkmark.outline.boundingBoxOfPath.midY == 0)
    }

    @Test(
        "A glyph is stroked as wide as the mock-up strokes it",
        arguments: [
            (FlowGlyph.cross, 2.1), (.checkmark, 2.4), (.library, 1.6), (.trash, 1.9), (.plus, 2.4), (.undo, 1.9),
            (.redo, 1.9)
        ]
    )
    func lineWidth(glyph: FlowGlyph, width: Double) {
        #expect(Double(glyph.lineWidth) == width)
    }

    @Test("The arrow of redo is the arrow of undo mirrored: undo points to the leading side, redo to the trailing")
    func turningArrows() {
        let undo = FlowGlyph.undo.outline.boundingBoxOfPath
        let redo = FlowGlyph.redo.outline.boundingBoxOfPath
        expectClose(redo, undo.applying(CGAffineTransform(scaleX: -1, y: 1)))
        #expect(undo.minX == -6)
        #expect(redo.maxX == 6)
    }
}
