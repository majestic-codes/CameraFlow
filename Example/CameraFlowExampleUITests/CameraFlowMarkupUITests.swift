//
//  CameraFlowMarkupUITests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// Drawing on a photo of the review: the canvas, undo and redo, the two ways out of it and the copy with the
/// drawing in the set the app receives.
@MainActor
final class CameraFlowMarkupUITests: XCTestCase, CameraFlowDriving {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Opens the drawing mode on the photo the review shows.
    private func openMarkup(in app: XCUIApplication) {
        tap(element(FlowElement.reviewMarkup, in: app))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.markupDone, in: app)))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.markupCanvas, in: app)))
    }

    /// Draws a stroke across the canvas with a finger.
    private func drawStroke(in app: XCUIApplication, from start: CGVector, to end: CGVector) {
        let canvas = element(FlowElement.markupCanvas, in: app)
        let from = canvas.coordinate(withNormalizedOffset: start)
        from.press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: end))
    }

    func testMarkupOpensOverThePhotoWithNothingToUndoAndCancelLeavesAtOnce() throws {
        let app = launchReview(photoCount: 1)

        openMarkup(in: app)

        let canvas = element(FlowElement.markupCanvas, in: app)
        XCTAssertEqual(canvas.label, "Drawing")
        XCTAssertFalse(element(FlowElement.markupUndo, in: app).isEnabled)
        XCTAssertFalse(element(FlowElement.markupRedo, in: app).isEnabled)
        XCTAssertFalse(element(FlowElement.accept, in: app).isEnabled)

        tap(element(FlowElement.markupCancel, in: app))

        XCTAssertTrue(waitUntilHittable(element(FlowElement.reviewMarkup, in: app)))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.accept, in: app)))
        XCTAssertFalse(app.staticTexts["Discard the drawing?"].exists)
        XCTAssertEqual(element(FlowElement.reviewTile(1), in: app).value as? String, "")
    }

    func testStrokeCanBeUndoneAndRedone() throws {
        let app = launchReview(photoCount: 1)
        openMarkup(in: app)
        let undo = element(FlowElement.markupUndo, in: app)
        let redo = element(FlowElement.markupRedo, in: app)

        drawStroke(in: app, from: CGVector(dx: 0.3, dy: 0.3), to: CGVector(dx: 0.7, dy: 0.5))

        XCTAssertTrue(waitUntilEnabled(undo))
        XCTAssertFalse(redo.isEnabled)

        tap(undo)

        XCTAssertTrue(waitUntilEnabled(redo))
        XCTAssertTrue(waitUntilDisabled(undo))

        tap(redo)

        XCTAssertTrue(waitUntilEnabled(undo))
        XCTAssertTrue(waitUntilDisabled(redo))
    }

    func testDoneKeepsTheDrawingAndTheTileSaysSo() throws {
        let app = launchReview(photoCount: 2)
        openMarkup(in: app)
        drawStroke(in: app, from: CGVector(dx: 0.2, dy: 0.2), to: CGVector(dx: 0.8, dy: 0.6))
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.markupUndo, in: app)))

        tap(element(FlowElement.markupDone, in: app))

        XCTAssertTrue(waitUntilHittable(element(FlowElement.reviewMarkup, in: app)))
        XCTAssertTrue(waitForValue("With a drawing", of: element(FlowElement.reviewTile(2), in: app)))
        XCTAssertEqual(element(FlowElement.reviewTile(1), in: app).value as? String, "")
        XCTAssertTrue(waitUntilNotHittable(element(FlowElement.markupDone, in: app)))
        XCTAssertFalse(element(FlowElement.notice, in: app).exists)
        XCTAssertEqual(element(FlowElement.badge, in: app).value as? String, "2")
    }

    func testCancelOfAChangedDrawingAsksFirstAndDiscardDropsIt() throws {
        let app = launchReview(photoCount: 1)
        openMarkup(in: app)
        drawStroke(in: app, from: CGVector(dx: 0.2, dy: 0.3), to: CGVector(dx: 0.8, dy: 0.3))
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.markupUndo, in: app)))

        tap(element(FlowElement.markupCancel, in: app))

        let discard = app.sheets.buttons["Discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Discard the drawing?"].exists)

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()

        XCTAssertTrue(discard.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(element(FlowElement.markupDone, in: app).isHittable)

        tap(element(FlowElement.markupCancel, in: app))
        XCTAssertTrue(discard.waitForExistence(timeout: timeout))
        tap(discard)

        XCTAssertTrue(waitUntilHittable(element(FlowElement.reviewMarkup, in: app)))
        XCTAssertEqual(element(FlowElement.reviewTile(1), in: app).value as? String, "")
    }

    func testDrawingOpensAgainWithItsStrokesAndNothingToUndo() throws {
        let app = launchReview(photoCount: 1)
        openMarkup(in: app)
        drawStroke(in: app, from: CGVector(dx: 0.2, dy: 0.2), to: CGVector(dx: 0.8, dy: 0.6))
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.markupUndo, in: app)))
        tap(element(FlowElement.markupDone, in: app))
        XCTAssertTrue(waitForValue("With a drawing", of: element(FlowElement.reviewTile(1), in: app)))

        openMarkup(in: app)

        XCTAssertFalse(element(FlowElement.markupUndo, in: app).isEnabled)
        tap(element(FlowElement.markupCancel, in: app))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.reviewMarkup, in: app)))
        XCTAssertEqual(element(FlowElement.reviewTile(1), in: app).value as? String, "With a drawing")
    }

    func testCheckMarkOfTheReviewHandsOverThePhotosLeftAndTheOneWithADrawing() throws {
        let app = launchReview(photoCount: 3)
        tap(element(FlowElement.reviewDelete, in: app))
        let delete = app.sheets.buttons["Delete photo"]
        XCTAssertTrue(delete.waitForExistence(timeout: timeout))
        tap(delete)
        XCTAssertTrue(waitForValue("2 of 2", of: element(FlowElement.reviewCounter, in: app)))
        openMarkup(in: app)
        drawStroke(in: app, from: CGVector(dx: 0.2, dy: 0.2), to: CGVector(dx: 0.8, dy: 0.6))
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.markupUndo, in: app)))
        tap(element(FlowElement.markupDone, in: app))
        XCTAssertTrue(waitForValue("With a drawing", of: element(FlowElement.reviewTile(2), in: app)))

        tap(element(FlowElement.accept, in: app))

        XCTAssertTrue(waitForPhotoCount(2, in: app))
        XCTAssertTrue(element(FlowElement.reviewCounter, in: app).waitForNonExistence(timeout: timeout))
    }
}
