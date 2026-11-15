//
//  FakeMarkupCanvas.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
@testable import CameraFlow

/// A canvas without a view: the test says what is on it and what its undo and redo can do, as a user would by
/// drawing, and the canvas tells its handler. With a gate it reads the drawing only once the gate has opened, as
/// the canvases of the system read it in the background.
@MainActor
final class FakeMarkupCanvas: MarkupCanvas {
    private(set) var canUndo = false
    private(set) var canRedo = false
    private(set) var hasChanges = false
    private(set) var undoCount = 0
    private(set) var redoCount = 0
    /// How many times the drawing was asked for.
    private(set) var readCount = 0
    /// What `currentDrawing()` gives back.
    private var drawing: MarkupDrawing?
    /// What `currentDrawing()` throws instead, nil for nothing.
    var readFailure: MarkupFailure?
    private var changeHandler: @MainActor () -> Void = {}
    private let readGate: CallGate?

    init(drawing: MarkupDrawing?, readGate: CallGate? = nil) {
        self.drawing = drawing
        self.readGate = readGate
    }

    /// The user draws, erases or steps through the history: the canvas holds `drawing` from now on.
    func change(to drawing: MarkupDrawing?, canUndo: Bool = true, canRedo: Bool = false, hasChanges: Bool = true) {
        self.drawing = drawing
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.hasChanges = hasChanges
        changeHandler()
    }

    func undo() {
        undoCount += 1
    }

    func redo() {
        redoCount += 1
    }

    func currentDrawing() async throws -> MarkupDrawing? {
        readCount += 1
        await readGate?.pass()
        if let readFailure {
            throw readFailure
        }
        return drawing
    }

    func setChangeHandler(_ handler: @escaping @MainActor () -> Void) {
        changeHandler = handler
    }
}

/// Opens fake canvases for a flow under test and keeps every opening, or fails the way the test tells it to.
@MainActor
final class RecordingCanvasOpener {
    struct Opening {
        let picture: CGImage
        let drawing: MarkupDrawing?
        let canvas: FakeMarkupCanvas
    }

    private(set) var openings: [Opening] = []
    /// What the next openings throw, nil for none.
    var failure: MarkupFailure?
    /// The gate the canvases opened from now on read their drawing at, nil for none.
    var readGate: CallGate?

    func open(picture: CGImage, drawing: MarkupDrawing?) throws -> FakeMarkupCanvas {
        if let failure {
            throw failure
        }
        let canvas = FakeMarkupCanvas(drawing: drawing, readGate: readGate)
        openings.append(Opening(picture: picture, drawing: drawing, canvas: canvas))
        return canvas
    }
}
