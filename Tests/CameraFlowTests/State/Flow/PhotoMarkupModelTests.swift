//
//  PhotoMarkupModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("Photo markup", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoMarkupModelTests {
    let harness = FlowHarness()

    // MARK: - Opening

    @Test("The Markup button opens an empty canvas over the picture of the photo the review shows")
    func start() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 3)
        let shown = flow.photoSet.photos[1]
        flow.review.show(shown.id)
        await flow.startMarkup()
        let opening = try #require(harness.canvasOpener.openings.last)
        let session = try #require(flow.markup.session)
        #expect(harness.canvasOpener.openings.count == 1)
        #expect(session.photoIdentifier == shown.id)
        #expect(session.canvas === opening.canvas)
        #expect(session.picture === flow.review.images.image(of: shown))
        #expect(opening.picture === session.picture)
        #expect(opening.drawing == nil)
        #expect(flow.markup.isOpen)
        #expect(flow.markup.canUndo == false)
        #expect(flow.markup.canRedo == false)
        #expect(flow.markup.hasChanges == false)
        #expect(flow.markup.notice == nil)
        flow.photoSet.discard()
    }

    @Test("The Markup button opens nothing in the shooting mode, and nothing more while a canvas is open")
    func startOnce() async throws {
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        await flow.startMarkup()
        #expect(flow.markup.isOpen == false)
        flow.showReview()
        await flow.startMarkup()
        await flow.startMarkup()
        #expect(harness.canvasOpener.openings.count == 1)
        flow.photoSet.discard()
    }

    @Test("A canvas that cannot be opened leaves the review as it is and says so, until the next try")
    func cannotOpen() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 1)
        harness.canvasOpener.failure = .engineUnavailable(.paperKit)
        await flow.startMarkup()
        #expect(flow.markup.isOpen == false)
        #expect(flow.markup.notice == .cannotOpen)
        #expect(FlowText(.system).notice(for: flow) == "Markup could not be opened")
        harness.canvasOpener.failure = nil
        await flow.startMarkup()
        #expect(flow.markup.isOpen)
        #expect(flow.markup.notice == nil)
        flow.photoSet.discard()
    }

    // MARK: - Undo and redo

    @Test("Undo, redo and the changes follow the canvas with every change of the drawing")
    func followsCanvas() async throws {
        let (flow, canvas) = try await harness.makeDrawnFlow()
        canvas.change(to: try FlowTestSupport.makeDrawing())
        #expect(flow.markup.canUndo)
        #expect(flow.markup.canRedo == false)
        #expect(flow.markup.hasChanges)
        canvas.change(to: nil, canUndo: false, canRedo: true, hasChanges: false)
        #expect(flow.markup.canUndo == false)
        #expect(flow.markup.canRedo)
        #expect(flow.markup.hasChanges == false)
        flow.photoSet.discard()
    }

    @Test("Undo and redo reach the canvas only while it can do them")
    func undoAndRedo() async throws {
        let (flow, canvas) = try await harness.makeDrawnFlow()
        flow.markup.undo()
        flow.markup.redo()
        #expect(canvas.undoCount == 0)
        #expect(canvas.redoCount == 0)
        canvas.change(to: try FlowTestSupport.makeDrawing(), canUndo: true, canRedo: true)
        flow.markup.undo()
        flow.markup.redo()
        #expect(canvas.undoCount == 1)
        #expect(canvas.redoCount == 1)
        flow.photoSet.discard()
    }

    // MARK: - Cancel

    @Test("Cancel closes a canvas without changes at once and leaves the photo as it was")
    func cancelUnchanged() async throws {
        let (flow, _) = try await harness.makeDrawnFlow()
        flow.markup.cancel()
        #expect(flow.markup.isOpen == false)
        #expect(flow.markup.isDiscardConfirmationPresented == false)
        #expect(flow.photoSet.photos.contains(where: \.hasDrawing) == false)
        #expect(flow.mode == .review)
        flow.photoSet.discard()
    }

    @Test("Cancel asks before a changed drawing is discarded, and a tap outside the dialog goes on drawing")
    func cancelAsks() async throws {
        let (flow, canvas) = try await harness.makeDrawnFlow()
        canvas.change(to: try FlowTestSupport.makeDrawing())
        flow.markup.cancel()
        #expect(flow.markup.isOpen)
        #expect(flow.markup.isDiscardConfirmationPresented)
        flow.markup.dismissDiscardConfirmation()
        #expect(flow.markup.isOpen)
        #expect(flow.markup.isDiscardConfirmationPresented == false)
        #expect(flow.markup.hasChanges)
        flow.photoSet.discard()
    }

    @Test("Discard closes the canvas and leaves the photo with the drawing it had")
    func discard() async throws {
        let (flow, canvas) = try await harness.makeDrawnFlow()
        let kept = try FlowTestSupport.makeDrawing("kept")
        canvas.change(to: kept)
        await flow.markup.finish()
        await flow.startMarkup()
        let reopened = try #require(harness.canvasOpener.openings.last?.canvas)
        reopened.change(to: try FlowTestSupport.makeDrawing("discarded"))
        flow.markup.cancel()
        flow.markup.discard()
        #expect(flow.markup.isOpen == false)
        #expect(flow.markup.isDiscardConfirmationPresented == false)
        #expect(flow.markup.canUndo == false)
        #expect(flow.markup.hasChanges == false)
        #expect(flow.review.currentPhoto?.drawing == kept)
        flow.photoSet.discard()
    }

    // MARK: - Done

    @Test("Done keeps the drawing of the canvas on the photo and returns to the review on the same photo")
    func finish() async throws {
        let (flow, canvas) = try await harness.makeDrawnFlow(photoCount: 3)
        let photo = try #require(flow.review.currentPhoto)
        let drawing = try FlowTestSupport.makeDrawing()
        canvas.change(to: drawing)
        await flow.markup.finish()
        #expect(flow.markup.isOpen == false)
        #expect(flow.markup.notice == nil)
        #expect(flow.mode == .review)
        #expect(flow.review.currentPhoto?.id == photo.id)
        #expect(flow.review.currentPhoto?.drawing == drawing)
        #expect(flow.photoSet.photos.map(\.hasDrawing) == [false, false, true])
        flow.photoSet.discard()
    }

    @Test("The same photo opens again with the drawing that was kept on it")
    func reopen() async throws {
        let (flow, canvas) = try await harness.makeDrawnFlow()
        let drawing = try FlowTestSupport.makeDrawing()
        canvas.change(to: drawing)
        await flow.markup.finish()
        await flow.startMarkup()
        #expect(harness.canvasOpener.openings.count == 2)
        #expect(harness.canvasOpener.openings.last?.drawing == drawing)
        #expect(flow.markup.hasChanges == false)
        flow.photoSet.discard()
    }

    @Test("Done on an emptied canvas takes the drawing off the photo")
    func finishEmpty() async throws {
        let (flow, canvas) = try await harness.makeDrawnFlow()
        canvas.change(to: try FlowTestSupport.makeDrawing())
        await flow.markup.finish()
        await flow.startMarkup()
        let reopened = try #require(harness.canvasOpener.openings.last?.canvas)
        reopened.change(to: nil)
        await flow.markup.finish()
        #expect(flow.review.currentPhoto?.hasDrawing == false)
        #expect(flow.markup.isOpen == false)
        flow.photoSet.discard()
    }

    @Test("The review has the picture of the drawing by the time the canvas closes")
    func finishRendersPicture() async throws {
        let flow = try await harness.makeReviewedFlow(photoCount: 1)
        let photo = try #require(flow.review.currentPhoto)
        await flow.review.images.prepare([photo], maximumPixelSize: 80)
        await flow.startMarkup()
        let canvas = try #require(harness.canvasOpener.openings.last?.canvas)
        let drawing = try FlowTestSupport.makeDrawing()
        canvas.change(to: drawing)
        await flow.markup.finish()
        let drawn = try #require(flow.review.currentPhoto)
        #expect(flow.review.images.drawingImage(of: drawn)?.width == 80)
        #expect(await harness.renderer.pictures.map(\.drawing) == [drawing])
        flow.photoSet.discard()
    }

    @Test("A drawing that cannot be read leaves the canvas open and the photo as it was, and says so")
    func cannotKeep() async throws {
        let (flow, canvas) = try await harness.makeDrawnFlow()
        canvas.change(to: try FlowTestSupport.makeDrawing())
        canvas.readFailure = .unencodableDrawing(.paperKit, "test")
        await flow.markup.finish()
        #expect(flow.markup.isOpen)
        #expect(flow.markup.isFinishing == false)
        #expect(flow.markup.notice == .cannotKeep)
        #expect(FlowText(.system).notice(for: flow) == "The drawing could not be saved")
        #expect(flow.review.currentPhoto?.hasDrawing == false)
        canvas.readFailure = nil
        await flow.markup.finish()
        #expect(flow.markup.isOpen == false)
        #expect(flow.markup.notice == nil)
        #expect(flow.review.currentPhoto?.hasDrawing == true)
        flow.photoSet.discard()
    }

    @Test("A canvas that has closed no longer moves undo and redo")
    func closedCanvas() async throws {
        let (flow, canvas) = try await harness.makeDrawnFlow()
        flow.markup.cancel()
        canvas.change(to: try FlowTestSupport.makeDrawing())
        #expect(flow.markup.canUndo == false)
        #expect(flow.markup.hasChanges == false)
        flow.photoSet.discard()
    }

    // MARK: - The flow around the drawing

    @Test("While a photo is drawn on, the set is not handed over and the camera does not come back")
    func flowWaits() async throws {
        let (flow, _) = try await harness.makeDrawnFlow()
        #expect(flow.canAccept == false)
        await flow.accept()
        await flow.showShooting()
        #expect(harness.outcome.handedOver.isEmpty)
        #expect(flow.mode == .review)
        flow.markup.cancel()
        #expect(flow.canAccept)
        flow.photoSet.discard()
    }

    @Test("The delete dialog of a photo with a drawing knows that the drawing goes with it")
    func deleteWithDrawing() async throws {
        let (flow, canvas) = try await harness.makeDrawnFlow()
        canvas.change(to: try FlowTestSupport.makeDrawing())
        await flow.markup.finish()
        flow.review.requestDelete()
        #expect(flow.review.deleteConfirmation?.hasDrawing == true)
        flow.photoSet.discard()
    }
}
