//
//  EngineDrawing.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import PaperKit
import PencilKit

/// A drawing as the engine that shows it holds it on a canvas: PencilKit's `PKDrawing` or PaperKit's `PaperMarkup`.
protocol EngineDrawing: Equatable, Sendable {
    /// The engine that holds drawings of this kind.
    static var engine: MarkupEngine { get }

    /// True when nothing of the drawing renders.
    var isEmpty: Bool { get }

    /// The engine's reading of a stored drawing. Fails with `MarkupFailure.undecodableDrawing`.
    init(decoding drawing: MarkupDrawing) throws

    /// A drawing with nothing on it, on a canvas of `size`.
    init(emptyCanvasOf size: CGSize)

    /// The drawing with everything on it moved by `transform`, on a canvas of `size`.
    func transformed(by transform: CGAffineTransform, onCanvasOf size: CGSize) -> Self

    /// The engine's serialised form of the drawing. Fails with `MarkupFailure.unencodableDrawing`.
    func serialized() async throws -> Data
}

extension PKDrawing: EngineDrawing {
    static var engine: MarkupEngine {
        .pencilKit
    }

    /// True when the drawing has no strokes.
    var isEmpty: Bool {
        strokes.isEmpty
    }

    init(decoding drawing: MarkupDrawing) throws {
        self = try drawing.pencilDrawing()
    }

    /// A PencilKit drawing has no canvas of its own: its strokes lie wherever they were drawn.
    init(emptyCanvasOf size: CGSize) {
        self.init()
    }

    func transformed(by transform: CGAffineTransform, onCanvasOf size: CGSize) -> PKDrawing {
        transformed(using: transform)
    }

    func serialized() -> Data {
        dataRepresentation()
    }
}

@available(iOS 26, macOS 26, *)
extension PaperMarkup: EngineDrawing {
    static var engine: MarkupEngine {
        .paperKit
    }

    /// True when nothing renders: no strokes and no inserted text, shape, image or sticker.
    var isEmpty: Bool {
        contentsRenderFrame.isNull
    }

    init(decoding drawing: MarkupDrawing) throws {
        self = try drawing.paperMarkup()
    }

    init(emptyCanvasOf size: CGSize) {
        self.init(bounds: CGRect(origin: .zero, size: size))
    }

    func transformed(by transform: CGAffineTransform, onCanvasOf size: CGSize) -> PaperMarkup {
        var markup = self
        markup.transformContent(transform)
        markup.bounds = CGRect(origin: .zero, size: size)
        return markup
    }

    func serialized() async throws -> Data {
        do {
            return try await dataRepresentation()
        } catch {
            throw MarkupFailure.unencodableDrawing(.paperKit, String(describing: error))
        }
    }
}
