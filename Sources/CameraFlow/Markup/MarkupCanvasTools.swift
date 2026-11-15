//
//  MarkupCanvasTools.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import PencilKit

/// The system tool picker of a canvas, in the dark appearance of the flow, and the undo manager of the drawing on
/// the canvas. The picker is up from the moment the canvas is open and on screen, whichever comes last, until the
/// canvas leaves the screen.
///
/// The picker offers the system's Apple Pencil setting, and both engines follow it: Apple Pencil draws, and a
/// finger draws unless the setting keeps drawing to Apple Pencil.
@MainActor
final class MarkupCanvasTools {
    let toolPicker = PKToolPicker.makeDark()
    private let undoObservation = MarkupUndoObservation()
    private let onUndoStateChange: @MainActor () -> Void
    private var presence = MarkupToolsPresence<any EngineCanvas>()

    /// `onUndoStateChange` hears every change of what the canvas can undo and redo while the picker is up.
    init(onUndoStateChange: @escaping @MainActor () -> Void) {
        self.onUndoStateChange = onUndoStateChange
    }

    var canUndo: Bool {
        presence.canvas?.undoManager?.canUndo == true
    }

    var canRedo: Bool {
        presence.canvas?.undoManager?.canRedo == true
    }

    func undo() {
        presence.canvas?.undoManager?.undo()
    }

    func redo() {
        presence.canvas?.undoManager?.redo()
    }

    /// The canvas took its size, drawn with `engineCanvas` from now on.
    func open(_ engineCanvas: any EngineCanvas) {
        if let canvas = presence.open(engineCanvas) {
            show(canvas)
        }
    }

    /// The canvas came on screen.
    func appear() {
        if let canvas = presence.appear() {
            show(canvas)
        }
    }

    /// The canvas leaves the screen.
    func disappear() {
        undoObservation.stop()
        presence.disappear()?.giveUpTools(of: toolPicker)
    }

    /// The canvas gets the undo manager of its window, so there is none before it is on screen.
    private func show(_ canvas: any EngineCanvas) {
        canvas.takeTools(of: toolPicker)
        undoObservation.observe(canvas.undoManager, onChange: onUndoStateChange)
    }
}
#endif
