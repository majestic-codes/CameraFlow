//
//  PaperMarkupFixture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import PaperKit
@testable import CameraFlow

/// PaperKit drawings made of the strokes of `PencilStrokeFixture`.
enum PaperMarkupFixture {

    /// The strokes of a PencilKit fixture as a PaperKit drawing on a canvas of the same size.
    @available(iOS 26, macOS 26, *)
    static func drawing(of pencilFixture: MarkupDrawing) async throws -> MarkupDrawing {
        var markup = PaperMarkup(bounds: CGRect(origin: .zero, size: pencilFixture.canvasSize))
        markup.append(contentsOf: try pencilFixture.pencilDrawing())
        let data = try await markup.dataRepresentation()
        return try MarkupDrawing(engine: .paperKit, data: data, canvasSize: pencilFixture.canvasSize)
    }
}
