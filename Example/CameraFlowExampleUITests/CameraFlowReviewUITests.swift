//
//  CameraFlowReviewUITests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// The review of the set: the mode switch, the pages and the strip, deleting a photo, and the two ways out of the
/// flow.
@MainActor
final class CameraFlowReviewUITests: XCTestCase, CameraFlowDriving {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Mode switch

    func testModeSwitchOpensTheReviewOnTheLastPhotoAndReturnsToTheCamera() throws {
        let app = launchFlowWithPhotos(2)
        let shutter = element(FlowElement.shutter, in: app)
        let counter = element(FlowElement.reviewCounter, in: app)
        XCTAssertTrue(shutter.isEnabled)
        XCTAssertTrue(element(FlowElement.modeShooting, in: app).isSelected)

        tap(element(FlowElement.modeReview, in: app))

        XCTAssertTrue(waitForValue("2 of 2", of: counter))
        XCTAssertTrue(waitUntilSelected(element(FlowElement.modeReview, in: app)))
        XCTAssertTrue(waitUntilSelected(element(FlowElement.reviewTile(2), in: app)))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.reviewDelete, in: app)))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.reviewMarkup, in: app)))
        XCTAssertTrue(element(FlowElement.accept, in: app).isEnabled)

        tap(element(FlowElement.modeShooting, in: app))

        XCTAssertTrue(waitUntilEnabled(shutter))
        XCTAssertTrue(waitUntilSelected(element(FlowElement.modeShooting, in: app)))
        XCTAssertTrue(waitUntilNotHittable(element(FlowElement.reviewDelete, in: app)))
        takePhoto(in: app, expecting: 3)
    }

    func testDraggingTheSwitchChangesTheMode() throws {
        let app = launchFlowWithPhotos(1)
        let shooting = element(FlowElement.modeShooting, in: app)
        let review = element(FlowElement.modeReview, in: app)
        XCTAssertTrue(waitUntilEnabled(review))

        let start = shooting.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = review.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertTrue(waitUntilSelected(review))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.reviewDelete, in: app)))

        end.press(forDuration: 0.1, thenDragTo: start)

        XCTAssertTrue(waitUntilSelected(shooting))
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
    }

    func testReviewOfAnEmptySetCannotBeOpened() throws {
        let app = launchFlow()
        let review = element(FlowElement.modeReview, in: app)
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
        XCTAssertFalse(review.isEnabled)

        tap(review)

        XCTAssertTrue(element(FlowElement.modeShooting, in: app).isSelected)
        XCTAssertTrue(element(FlowElement.shutter, in: app).isEnabled)
        XCTAssertFalse(element(FlowElement.reviewCounter, in: app).exists)
    }

    // MARK: - Pages and strip

    /// Drags the page of the review across the screen, by coordinates: the pages share one identifier.
    private func dragPage(in app: XCUIApplication, from start: CGFloat, to end: CGFloat) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: start, dy: 0.45))
        from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: end, dy: 0.45)))
    }

    private func showPreviousPhoto(in app: XCUIApplication) {
        dragPage(in: app, from: 0.2, to: 0.8)
    }

    private func showNextPhoto(in app: XCUIApplication) {
        dragPage(in: app, from: 0.8, to: 0.2)
    }

    func testSwipingPagesThroughThePhotosAndTheStripFollows() throws {
        let app = launchReview(photoCount: 3)
        let counter = element(FlowElement.reviewCounter, in: app)
        XCTAssertTrue(waitForValue("3 of 3", of: counter))

        showPreviousPhoto(in: app)
        XCTAssertTrue(waitForValue("2 of 3", of: counter))
        XCTAssertTrue(waitUntilSelected(element(FlowElement.reviewTile(2), in: app)))

        showPreviousPhoto(in: app)
        XCTAssertTrue(waitForValue("1 of 3", of: counter))
        XCTAssertTrue(waitUntilSelected(element(FlowElement.reviewTile(1), in: app)))

        showPreviousPhoto(in: app)
        XCTAssertTrue(waitForValue("1 of 3", of: counter))

        showNextPhoto(in: app)
        XCTAssertTrue(waitForValue("2 of 3", of: counter))
        XCTAssertFalse(element(FlowElement.reviewTile(1), in: app).isSelected)
    }

    func testTileOfTheStripShowsItsPhoto() throws {
        let app = launchReview(photoCount: 3)
        let counter = element(FlowElement.reviewCounter, in: app)
        XCTAssertTrue(waitForValue("3 of 3", of: counter))
        XCTAssertEqual(element(FlowElement.reviewTile(1), in: app).label, "Photo 1 of 3")

        tap(element(FlowElement.reviewTile(1), in: app))

        XCTAssertTrue(waitForValue("1 of 3", of: counter))
        XCTAssertTrue(waitUntilSelected(element(FlowElement.reviewTile(1), in: app)))
        XCTAssertFalse(element(FlowElement.reviewTile(3), in: app).isSelected)
    }

    // MARK: - Delete

    func testDeleteAsksFirstAndATapOutsideKeepsThePhoto() throws {
        let app = launchReview(photoCount: 2)
        let counter = element(FlowElement.reviewCounter, in: app)

        tap(element(FlowElement.reviewDelete, in: app))

        let delete = app.sheets.buttons["Delete photo"]
        XCTAssertTrue(delete.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Delete this photo?"].exists)
        XCTAssertTrue(app.staticTexts["This photo is not saved anywhere else."].exists)

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()

        XCTAssertTrue(delete.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitForValue("2 of 2", of: counter))
        XCTAssertEqual(element(FlowElement.badge, in: app).value as? String, "2")
    }

    func testDeleteRemovesThePhotoAndShowsItsNeighbour() throws {
        let app = launchReview(photoCount: 3)
        let counter = element(FlowElement.reviewCounter, in: app)
        tap(element(FlowElement.reviewTile(2), in: app))
        XCTAssertTrue(waitForValue("2 of 3", of: counter))

        tap(element(FlowElement.reviewDelete, in: app))
        let delete = app.sheets.buttons["Delete photo"]
        XCTAssertTrue(delete.waitForExistence(timeout: timeout))
        tap(delete)

        XCTAssertTrue(waitForValue("2 of 2", of: counter))
        XCTAssertTrue(waitForValue("2", of: element(FlowElement.badge, in: app)))
        XCTAssertTrue(element(FlowElement.reviewTile(3), in: app).waitForNonExistence(timeout: timeout))
    }

    func testDeletingTheOnlyPhotoReturnsToTheCamera() throws {
        let app = launchReview(photoCount: 1)

        tap(element(FlowElement.reviewDelete, in: app))
        let delete = app.sheets.buttons["Delete photo"]
        XCTAssertTrue(delete.waitForExistence(timeout: timeout))
        tap(delete)

        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
        XCTAssertTrue(waitUntilSelected(element(FlowElement.modeShooting, in: app)))
        XCTAssertTrue(element(FlowElement.badge, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertFalse(element(FlowElement.accept, in: app).isEnabled)
    }

    // MARK: - Accept

    func testCheckMarkHandsThePhotosToTheAppAndClosesTheFlow() throws {
        let app = launchFlowWithPhotos(2)
        XCTAssertTrue(waitForPhotoCount(0, in: app))

        tap(element(FlowElement.accept, in: app))

        XCTAssertTrue(waitForPhotoCount(2, in: app))
        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(app.buttons[ExampleElement.openCameraFlow]))
    }

    func testPhotosAreHandedOverWithSavingOn() throws {
        let arguments = ["-cameraFlowAccess", "library", "-cameraFlowNoOnboarding"]
        let app = launchFlowWithPhotos(2, arguments, saving: ["-cameraFlowSaveToLibrary"])
        XCTAssertEqual(element(FlowElement.save, in: app).value as? String, "On")

        tap(element(FlowElement.accept, in: app))

        XCTAssertTrue(waitForPhotoCount(2, in: app))
        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForNonExistence(timeout: timeout))
    }

    // MARK: - Exit

    func testCrossOfAnEmptySetLeavesAtOnce() throws {
        let app = launchFlow()
        let exit = element(FlowElement.exit, in: app)
        XCTAssertTrue(waitUntilHittable(exit))

        tap(exit)

        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(waitUntilHittable(app.buttons[ExampleElement.openCameraFlow]))
        XCTAssertTrue(waitForPhotoCount(0, in: app))
    }

    func testCrossOfASetWithPhotosAsksFirstAndStayKeepsTheSet() throws {
        let app = launchFlowWithPhotos(2)

        tap(element(FlowElement.exit, in: app))

        let alert = app.alerts["Leave without the photos?"]
        XCTAssertTrue(alert.waitForExistence(timeout: timeout))
        let message = "The set has 2 photos. The ones taken with the camera will be gone for good."
        XCTAssertTrue(alert.staticTexts[message].exists)
        XCTAssertTrue(alert.buttons["Leave"].exists)

        alert.buttons["Stay"].tap()

        XCTAssertTrue(alert.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
        XCTAssertEqual(element(FlowElement.badge, in: app).value as? String, "2")
        takePhoto(in: app, expecting: 3)
    }

    func testLeaveDiscardsTheSetAndTheAppGetsNothing() throws {
        let app = launchFlowWithPhotos(2)

        tap(element(FlowElement.exit, in: app))
        let alert = app.alerts["Leave without the photos?"]
        XCTAssertTrue(alert.waitForExistence(timeout: timeout))
        alert.buttons["Leave"].tap()

        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(app.buttons[ExampleElement.openCameraFlow]))
        XCTAssertTrue(waitForPhotoCount(0, in: app))
    }

    func testCrossOfTheReviewAsksAsWell() throws {
        let app = launchReview(photoCount: 1)

        tap(element(FlowElement.exit, in: app))

        let alert = app.alerts["Leave without the photos?"]
        XCTAssertTrue(alert.waitForExistence(timeout: timeout))
        alert.buttons["Stay"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitForValue("1 of 1", of: element(FlowElement.reviewCounter, in: app)))
        XCTAssertTrue(element(FlowElement.reviewDelete, in: app).isHittable)
    }

    // MARK: - Ukrainian

    func testReviewAndItsDialogsInUkrainian() throws {
        let app = launchReview(photoCount: 1, language: "uk", region: "UA")

        XCTAssertEqual(element(FlowElement.reviewDelete, in: app).label, "Видалити фото")
        XCTAssertEqual(element(FlowElement.reviewMarkup, in: app).label, "Розмітка")
        XCTAssertEqual(element(FlowElement.modeReview, in: app).label, "Перегляд")
        XCTAssertEqual(element(FlowElement.modeShooting, in: app).label, "Зйомка")
        XCTAssertEqual(element(FlowElement.accept, in: app).label, "Готово")
        XCTAssertEqual(element(FlowElement.exit, in: app).label, "Закрити")

        tap(element(FlowElement.reviewDelete, in: app))
        XCTAssertTrue(app.staticTexts["Видалити це фото?"].waitForExistence(timeout: timeout))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
        XCTAssertTrue(app.staticTexts["Видалити це фото?"].waitForNonExistence(timeout: timeout))

        tap(element(FlowElement.exit, in: app))
        let alert = app.alerts["Вийти без фото?"]
        XCTAssertTrue(alert.waitForExistence(timeout: timeout))
        XCTAssertTrue(alert.buttons["Вийти"].exists)
        alert.buttons["Залишитись"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: timeout))

        tap(element(FlowElement.reviewMarkup, in: app))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.markupDone, in: app)))
        XCTAssertEqual(element(FlowElement.markupCancel, in: app).label, "Скасувати")
        XCTAssertEqual(element(FlowElement.markupDone, in: app).label, "Готово")
    }
}
