//
//  MarkupCanvasFactory.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import CoreGraphics

/// Opens canvases with the engine of the system: PaperKit on iOS 26 and later, PencilKit before it.
@MainActor
enum MarkupCanvasFactory {
    /// The engine a new drawing is made with.
    private static var systemEngine: MarkupEngine {
        if #available(iOS 26, *) {
            .paperKit
        } else {
            .pencilKit
        }
    }

    /// A canvas over `photo`, the upright picture the screen shows, with `drawing` on it to go on with.
    ///
    /// A stored drawing opens in the engine that made it. Fails with `MarkupFailure.engineUnavailable` when the
    /// system does not have that engine, and with `MarkupFailure.undecodableDrawing` when the engine cannot read it.
    static func makeCanvas(photo: CGImage, drawing: MarkupDrawing?) throws -> EmbeddedMarkupCanvas {
        switch drawing?.engine ?? systemEngine {
        case .pencilKit:
            return try EmbeddedMarkupCanvas(PencilMarkupCanvasController(drawing: drawing))
        case .paperKit:
            guard #available(iOS 26, *) else {
                throw MarkupFailure.engineUnavailable(.paperKit)
            }
            return try EmbeddedMarkupCanvas(PaperMarkupCanvasController(photo: photo, drawing: drawing))
        }
    }
}
#endif
