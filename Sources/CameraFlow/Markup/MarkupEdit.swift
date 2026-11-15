//
//  MarkupEdit.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// One editing of a drawing on a canvas, whichever engine shows it: the drawing the canvas was opened with, what
/// the canvas shows from the moment it takes its size, and the drawing that comes out of what it shows later.
///
/// A canvas of PaperKit holds its drawings through this generic class, so that it never stores a PaperKit value
/// itself.
@MainActor
final class MarkupEdit<Drawing: EngineDrawing> {
    /// What the canvas showed when it took its size, and that size.
    private struct Opening {
        let drawing: Drawing
        let canvasSize: CGSize
    }

    /// The drawing the canvas was opened with, as it was kept and as its engine reads it.
    private let stored: (drawing: MarkupDrawing, engineDrawing: Drawing)?
    private var opening: Opening?

    /// Fails with `MarkupFailure.undecodableDrawing` when the engine cannot read `drawing`.
    init(_ drawing: MarkupDrawing?) throws {
        stored = try drawing.map { ($0, try Drawing(decoding: $0)) }
    }

    /// Whether the canvas has taken its size.
    var isOpen: Bool {
        opening != nil
    }

    /// The canvas takes its size, which it keeps: gives back what it shows from now on, the stored drawing, scaled
    /// when it was made on a canvas of another size, or an empty drawing.
    func open(canvasSize: CGSize) -> Drawing {
        let drawing = openingDrawing(canvasSize: canvasSize)
        opening = Opening(drawing: drawing, canvasSize: canvasSize)
        return drawing
    }

    /// The drawing the canvas shows when it is not the one the canvas opened with. A canvas that opened empty and
    /// is empty again has none, and so has a canvas that has not taken its size or has nothing to read yet.
    func changedDrawing(_ drawing: Drawing?) -> Drawing? {
        guard let opening, let drawing else {
            return nil
        }
        let isStillEmpty = drawing.isEmpty && opening.drawing.isEmpty
        return isStillEmpty || drawing == opening.drawing ? nil : drawing
    }

    /// The drawing to keep of what the canvas shows, made on the canvas of the size it took: the stored drawing
    /// while there is no change, nil when the canvas is empty.
    func currentDrawing(_ drawing: Drawing?) async throws -> MarkupDrawing? {
        guard let opening, let changed = changedDrawing(drawing) else {
            return stored?.drawing
        }
        guard changed.isEmpty == false else {
            return nil
        }
        let data = try await changed.serialized()
        return try MarkupDrawing(engine: Drawing.engine, data: data, canvasSize: opening.canvasSize)
    }

    private func openingDrawing(canvasSize: CGSize) -> Drawing {
        guard let stored else {
            return Drawing(emptyCanvasOf: canvasSize)
        }
        guard stored.drawing.canvasSize != canvasSize else {
            return stored.engineDrawing
        }
        let scaling = stored.drawing.scaling(toCanvasOf: canvasSize)
        return stored.engineDrawing.transformed(by: scaling, onCanvasOf: canvasSize)
    }
}
