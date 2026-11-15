//
//  MarkupDrawing.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// The system framework a drawing is made with. A drawing is opened, shown and written by the engine that made it.
enum MarkupEngine: Sendable, Equatable {
    /// Strokes only. iOS 17 and later.
    case pencilKit
    /// Strokes, text, shapes and stickers. iOS 26 and later.
    case paperKit
}

/// A drawing over a photo, as it is kept between two openings of the canvas.
///
/// The canvas covers the whole upright photo, so a place on the canvas is the same fraction of the photo at any
/// size. Two values of the same drawing may differ in `data`: PaperKit does not serialise a drawing the same way
/// twice.
struct MarkupDrawing: Sendable, Equatable {
    /// Told apart from the drawings made after it by a comparison that does not read `data`. A copy of the value
    /// keeps it. Two drawings made apart are equal when their contents are, whatever their identifiers say.
    let identifier = UUID()
    let engine: MarkupEngine
    /// The drawing in the engine's own serialised form.
    let data: Data
    /// The size of the canvas the drawing was made on, in points.
    let canvasSize: CGSize

    /// Fails with `MarkupFailure.emptyCanvas` for a canvas without an area, which nothing can be scaled from.
    init(engine: MarkupEngine, data: Data, canvasSize: CGSize) throws {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            throw MarkupFailure.emptyCanvas(canvasSize)
        }
        self.engine = engine
        self.data = data
        self.canvasSize = canvasSize
    }

    static func == (left: Self, right: Self) -> Bool {
        left.engine == right.engine && left.canvasSize == right.canvasSize && left.data == right.data
    }

    /// Takes a place on the canvas the drawing was made on to the same place on a canvas of another size.
    func scaling(toCanvasOf size: CGSize) -> CGAffineTransform {
        CGAffineTransform(scaleX: size.width / canvasSize.width, y: size.height / canvasSize.height)
    }
}
