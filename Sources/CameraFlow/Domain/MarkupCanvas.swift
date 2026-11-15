//
//  MarkupCanvas.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Opens a canvas over a photo, the upright picture the screen shows, with a stored drawing on it to go on with.
/// Every failure is a `MarkupFailure`.
typealias MarkupCanvasOpener<Canvas: MarkupCanvas> = @MainActor (
    _ photo: CGImage,
    _ drawing: MarkupDrawing?
) throws -> Canvas

/// The canvas open over one photo, as the model of the drawing mode drives it.
///
/// The canvas takes its size when it is first laid out. Until then it holds the drawing it was opened with.
@MainActor
protocol MarkupCanvas: AnyObject {
    var canUndo: Bool { get }
    var canRedo: Bool { get }
    /// True when the drawing is not the one the canvas opened with. An empty canvas that is empty again has no
    /// changes. The engines tell drawings apart by their history of edits, so a drawing that undo brought back may
    /// still count as changed.
    var hasChanges: Bool { get }
    func undo()
    func redo()
    /// The drawing as it is now, nil when the canvas is empty. A canvas without changes gives back the drawing it
    /// was opened with.
    func currentDrawing() async throws -> MarkupDrawing?
    /// Receives every change of the drawing and of what undo and redo can do, after which the properties above
    /// are read anew.
    func setChangeHandler(_ handler: @escaping @MainActor () -> Void)
}
