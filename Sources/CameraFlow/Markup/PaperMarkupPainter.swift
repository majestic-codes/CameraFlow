//
//  PaperMarkupPainter.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import PaperKit

/// Paints a PaperKit drawing: its strokes and everything inserted into it.
@available(iOS 26, macOS 26, *)
struct PaperMarkupPainter: MarkupPainter {
    private let markup: PaperMarkup
    private let canvas: CGRect

    init(_ drawing: MarkupDrawing) throws {
        markup = try drawing.paperMarkup()
        canvas = CGRect(origin: .zero, size: drawing.canvasSize)
    }

    func paint(in context: CGContext, size: CGSize) async {
        context.saveGState()
        // PaperKit draws in the points of its canvas, from the top left corner down.
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: size.width / canvas.width, y: -size.height / canvas.height)
        // Without the dark appearance the ink comes out black instead of the colour it has on screen.
        await markup.draw(in: context, frame: canvas, options: RenderingOptions(darkUserInterfaceStyle: true))
        context.restoreGState()
    }
}
