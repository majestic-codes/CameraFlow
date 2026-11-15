//
//  CameraFlowLibraryUITests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// Photos from the photo library: the system picker over the flow, from the button beside the shutter and from
/// the "+" tile of the review. The picker is the system's own, and its photos are the ones of the simulator.
@MainActor
final class CameraFlowLibraryUITests: XCTestCase, CameraFlowDriving {

    override func setUp() {
        continueAfterFailure = false
    }

    /// The photos the picker shows, whatever the system calls its grid: it reads each as "Photo, " and its date.
    private func pickerPhotos(in app: XCUIApplication) -> XCUIElementQuery {
        app.images.matching(NSPredicate(format: "label BEGINSWITH 'Photo, ' OR label BEGINSWITH 'Screenshot, '"))
    }

    private func cancelButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == 'Cancel' OR identifier == 'Cancel'")).firstMatch
    }

    /// The button that confirms the picks: "Add" before iOS 26 and a check mark with the label "Done" from it. The
    /// flow's own check mark has that label too, and stays in the hierarchy under the picker.
    private func confirmButton(in app: XCUIApplication) -> XCUIElement {
        let isConfirm = "(label == 'Add' OR label == 'Done') AND NOT (identifier BEGINSWITH 'flow.')"
        return app.buttons.matching(NSPredicate(format: isConfirm)).firstMatch
    }

    func testLibraryButtonOpensThePickerAndCancelReturnsToTheCameraWithAnEmptySet() throws {
        let app = launchFlow()
        tap(element(FlowElement.library, in: app))

        let cancel = cancelButton(in: app)
        XCTAssertTrue(cancel.waitForExistence(timeout: timeout))
        attachScreenshot(named: "library-picker")
        tap(cancel)

        XCTAssertTrue(cancel.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
        XCTAssertFalse(element(FlowElement.badge, in: app).exists)
        takePhoto(in: app, expecting: 1)
    }

    func testPhotoPickedFromTheLibraryJoinsTheSetAndIsHandedOver() throws {
        let app = launchFlowWithPhotos(1)
        tap(element(FlowElement.library, in: app))
        XCTAssertTrue(cancelButton(in: app).waitForExistence(timeout: timeout))
        let photo = pickerPhotos(in: app).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: timeout), "the photo library of the simulator has no photo")

        tapMiddle(of: photo)
        let confirm = confirmButton(in: app)
        XCTAssertTrue(confirm.waitForExistence(timeout: timeout))
        tap(confirm)

        XCTAssertTrue(confirm.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitForValue("2", of: element(FlowElement.badge, in: app), timeout: 30))
        XCTAssertTrue(element(FlowElement.modeShooting, in: app).isSelected)
        XCTAssertFalse(element(FlowElement.notice, in: app).exists)
        openReview(in: app)
        XCTAssertTrue(waitForValue("2 of 2", of: element(FlowElement.reviewCounter, in: app)))

        tap(element(FlowElement.accept, in: app))

        XCTAssertTrue(waitForPhotoCount(2, in: app))
    }

    func testPlusTileOfTheReviewOpensThePicker() throws {
        let app = launchReview(photoCount: 1)
        tap(element(FlowElement.reviewAdd, in: app))

        let cancel = cancelButton(in: app)
        XCTAssertTrue(cancel.waitForExistence(timeout: timeout))
        tap(cancel)

        XCTAssertTrue(cancel.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitForValue("1 of 1", of: element(FlowElement.reviewCounter, in: app)))
    }

    func testFlowWithoutThePhotoLibraryHasNoLibraryButtonAndNoPlusTile() throws {
        let app = launchFlowWithPhotos(1, ["-cameraFlowNoLibrary"])

        XCTAssertFalse(element(FlowElement.library, in: app).exists)
        openReview(in: app)
        XCTAssertFalse(element(FlowElement.reviewAdd, in: app).exists)
        XCTAssertTrue(element(FlowElement.reviewTile(1), in: app).exists)
    }
}
