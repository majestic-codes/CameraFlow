//
//  PhotoMarkupModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Observation
import os

private let logger = Logger.camera("PhotoMarkupModel")

/// The drawing mode over one photo of the review: the open canvas, what its undo and redo can do, and the three
/// ways out of it. Done keeps the drawing on the photo, cancel and discard leave the photo as it was.
@MainActor
@Observable
final class PhotoMarkupModel<Canvas: MarkupCanvas> {
    /// The canvas that is open, nil while nothing is being drawn.
    private(set) var session: MarkupSession<Canvas>?
    private(set) var canUndo = false
    private(set) var canRedo = false
    /// Whether the drawing on the canvas is another one than it opened with.
    private(set) var hasChanges = false
    /// Whether the dialog that asks before a changed drawing is discarded is up.
    private(set) var isDiscardConfirmationPresented = false
    /// True while done reads the drawing from the canvas.
    private(set) var isFinishing = false
    /// What went wrong last, nil once the drawing mode is used again.
    private(set) var notice: MarkupNotice?

    @ObservationIgnored private let photoSet: PhotoSetModel
    @ObservationIgnored private let images: ReviewImageModel
    @ObservationIgnored private let openCanvas: MarkupCanvasOpener<Canvas>

    init(photoSet: PhotoSetModel, images: ReviewImageModel, openCanvas: @escaping MarkupCanvasOpener<Canvas>) {
        self.photoSet = photoSet
        self.images = images
        self.openCanvas = openCanvas
    }

    var isOpen: Bool {
        session != nil
    }

    // MARK: - Opening

    /// Opens a canvas over a picture of the photo at least the size of the screen, with the drawing of the photo on
    /// it to go on with. A canvas that cannot be opened leaves the review as it is and says so.
    func start(on photo: FlowPhoto, picture: CGImage) {
        guard session == nil else { return }
        notice = nil
        let canvas: Canvas
        do {
            canvas = try openCanvas(picture, photo.drawing)
        } catch {
            logger.error("Cannot open the canvas: \(String(describing: error), privacy: .public)")
            notice = .cannotOpen
            return
        }
        canvas.setChangeHandler { [weak self, weak canvas] in
            guard let self, let canvas, session?.canvas === canvas else { return }
            readState(of: canvas)
        }
        session = MarkupSession(photoIdentifier: photo.id, picture: picture, canvas: canvas)
        readState(of: canvas)
    }

    private func readState(of canvas: Canvas) {
        canUndo = canvas.canUndo
        canRedo = canvas.canRedo
        hasChanges = canvas.hasChanges
    }

    // MARK: - Drawing

    func undo() {
        guard canUndo, !isFinishing else { return }
        session?.canvas.undo()
    }

    func redo() {
        guard canRedo, !isFinishing else { return }
        session?.canvas.redo()
    }

    // MARK: - Ways out

    /// Cancel: a canvas without changes closes at once, a changed one asks first.
    func cancel() {
        guard session != nil, !isFinishing else { return }
        if hasChanges {
            isDiscardConfirmationPresented = true
        } else {
            close()
        }
    }

    /// The dialog went away without its destructive answer, so the drawing goes on.
    func dismissDiscardConfirmation() {
        isDiscardConfirmationPresented = false
    }

    /// The destructive answer of the dialog: closes the canvas and leaves the photo as it was.
    func discard() {
        guard session != nil, !isFinishing else { return }
        close()
    }

    /// Done: keeps the drawing of the canvas on the photo, where an empty canvas takes the drawing off it, and
    /// closes the canvas once the review has the picture of the drawing to show. A drawing that cannot be read
    /// leaves the canvas open and says so.
    func finish() async {
        guard let session, !isFinishing else { return }
        isFinishing = true
        defer { isFinishing = false }
        notice = nil
        let drawing: MarkupDrawing?
        do {
            drawing = try await session.canvas.currentDrawing()
        } catch {
            logger.error("Cannot read the drawing of the canvas: \(String(describing: error), privacy: .public)")
            notice = .cannotKeep
            return
        }
        photoSet.setDrawing(drawing, ofPhoto: session.photoIdentifier)
        if let photo = photoSet.photos.first(where: { $0.id == session.photoIdentifier }) {
            await images.renderDrawing(of: photo)
        }
        close()
    }

    private func close() {
        session = nil
        canUndo = false
        canRedo = false
        hasChanges = false
        isDiscardConfirmationPresented = false
    }
}
