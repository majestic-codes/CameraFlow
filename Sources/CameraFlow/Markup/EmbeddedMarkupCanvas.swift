//
//  EmbeddedMarkupCanvas.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import UIKit

/// The canvas of the screen, whichever engine draws it. The models of the flow are generic over their canvas, and
/// this is the one the screen runs them with, so the views always get a canvas with a view controller to show.
@MainActor
final class EmbeddedMarkupCanvas: EmbeddableMarkupCanvas {
    private let canvas: any EmbeddableMarkupCanvas

    init(_ canvas: any EmbeddableMarkupCanvas) {
        self.canvas = canvas
    }

    var viewController: UIViewController {
        canvas.viewController
    }

    var canUndo: Bool {
        canvas.canUndo
    }

    var canRedo: Bool {
        canvas.canRedo
    }

    var hasChanges: Bool {
        canvas.hasChanges
    }

    func undo() {
        canvas.undo()
    }

    func redo() {
        canvas.redo()
    }

    func currentDrawing() async throws -> MarkupDrawing? {
        try await canvas.currentDrawing()
    }

    func setChangeHandler(_ handler: @escaping @MainActor () -> Void) {
        canvas.setChangeHandler(handler)
    }
}
#endif
