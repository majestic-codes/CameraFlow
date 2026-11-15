//
//  EngineCanvas.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import PaperKit
import PencilKit
import UIKit

/// What an engine draws a canvas with, as the system tool picker drives it: PencilKit's `PKCanvasView` or
/// PaperKit's `PaperMarkupViewController`.
@MainActor
protocol EngineCanvas: AnyObject {
    /// The undo manager that holds the history of the drawing.
    var undoManager: UndoManager? { get }

    /// Shows `toolPicker` for the canvas and draws with the tools picked in it.
    func takeTools(of toolPicker: PKToolPicker)

    /// Hides `toolPicker` and stops drawing with its tools.
    func giveUpTools(of toolPicker: PKToolPicker)
}

extension PKCanvasView: EngineCanvas {

    func takeTools(of toolPicker: PKToolPicker) {
        toolPicker.show(for: self, observer: self)
    }

    func giveUpTools(of toolPicker: PKToolPicker) {
        toolPicker.hide(for: self, observer: self)
    }
}

@available(iOS 26, *)
extension PaperMarkupViewController: EngineCanvas {

    /// The picker shows for the editor's view, and PaperKit draws with the picker its responder state names.
    func takeTools(of toolPicker: PKToolPicker) {
        toolPicker.show(for: view, observer: self)
        pencilKitResponderState.activeToolPicker = toolPicker
        pencilKitResponderState.toolPickerVisibility = .visible
    }

    func giveUpTools(of toolPicker: PKToolPicker) {
        toolPicker.hide(for: view, observer: self)
    }
}
#endif
