//
//  CameraFlowEntryUITests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// How the flow is opened and what it keeps between two flows: the SwiftUI cover and the UIKit controller, the
/// preferences the app stores, the settings the flow remembers, the languages and the text sizes.
@MainActor
final class CameraFlowEntryUITests: XCTestCase, CameraFlowDriving {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Entry points

    func testButtonOfTheAppOpensTheFlowAndEveryFlowStartsEmpty() throws {
        let app = launchFlow(opening: [])
        let open = app.buttons[ExampleElement.openCameraFlow]
        XCTAssertTrue(waitUntilHittable(open))
        XCTAssertFalse(element(FlowElement.shutter, in: app).exists)

        tap(open)
        takePhoto(in: app, expecting: 1)
        tap(element(FlowElement.accept, in: app))
        XCTAssertTrue(waitForPhotoCount(1, in: app))
        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForNonExistence(timeout: timeout))

        XCTAssertTrue(waitUntilHittable(open))
        tap(open)

        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
        XCTAssertFalse(element(FlowElement.badge, in: app).exists)
        XCTAssertFalse(element(FlowElement.accept, in: app).isEnabled)
        takePhoto(in: app, expecting: 1)
        tap(element(FlowElement.accept, in: app))
        XCTAssertTrue(waitForPhotoCount(2, in: app))
    }

    func testUIKitControllerTakesPhotosHandsThemOverAndDismissesItself() throws {
        let app = launchFlow(opening: ["-cameraFlowUIKit"])

        takePhoto(in: app, expecting: 1)
        takePhoto(in: app, expecting: 2)
        openReview(in: app)
        XCTAssertTrue(waitForValue("2 of 2", of: element(FlowElement.reviewCounter, in: app)))
        tap(element(FlowElement.accept, in: app))

        XCTAssertTrue(waitForPhotoCount(2, in: app))
        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(app.buttons[ExampleElement.openCameraFlowUIKit]))
    }

    func testUIKitControllerAsksBeforeASetIsLeftAndDismissesItselfOnLeave() throws {
        let app = launchFlow(opening: ["-cameraFlowUIKit"])
        takePhoto(in: app, expecting: 1)

        tap(element(FlowElement.exit, in: app))
        let alert = app.alerts["Leave without the photos?"]
        XCTAssertTrue(alert.waitForExistence(timeout: timeout))
        tap(alert.buttons["Leave"])

        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(app.buttons[ExampleElement.openCameraFlowUIKit]))
        XCTAssertTrue(waitForPhotoCount(0, in: app))
    }

    func testUIKitButtonOfTheAppOpensTheFlow() throws {
        let app = launchFlow(opening: [])
        let open = app.buttons[ExampleElement.openCameraFlowUIKit]
        XCTAssertTrue(waitUntilHittable(open))

        tap(open)

        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
        tap(element(FlowElement.exit, in: app))
        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(open))
    }

    func testRelaunchedAppOpensTheFlowWithAnEmptySet() throws {
        let first = launchFlowWithPhotos(2)
        first.terminate()

        let second = launchFlow()

        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: second)))
        XCTAssertFalse(element(FlowElement.badge, in: second).exists)
        XCTAssertFalse(element(FlowElement.modeReview, in: second).isEnabled)
        XCTAssertTrue(waitForPhotoCount(0, in: second))
    }

    // MARK: - Preferences the app stores

    func testAspectAndFlashComeBackWithTheStoredPreferences() throws {
        let first = launchFlow(["-cameraFlowSubPanel", "aspect"])
        XCTAssertTrue(waitUntilHittable(option("16:9", in: first)))
        tap(option("16:9", in: first))
        XCTAssertTrue(waitUntilSelected(option("16:9", in: first)))
        tap(element(FlowElement.subPanelBack, in: first))
        let flash = element(FlowElement.flash, in: first)
        XCTAssertTrue(waitUntilHittable(flash))
        XCTAssertTrue(waitForValue("Automatic", of: flash))
        tap(flash)
        XCTAssertTrue(waitForValue("On", of: flash))
        first.terminate()

        let second = launchFlow(resetsState: false, appliesStoredPreferences: true)
        XCTAssertTrue(waitForValue("On", of: element(FlowElement.flash, in: second)))
        let aspect = element(FlowElement.indicator("aspect"), in: second)
        XCTAssertTrue(waitForValue("16 by 9", of: aspect))
        let viewfinder = element(FlowElement.viewfinder, in: second)
        XCTAssertEqual(viewfinder.frame.height / viewfinder.frame.width, 16.0 / 9.0, accuracy: 0.01)

        // A change in a flow that opened with the stored preferences is stored as well.
        tap(aspect)
        XCTAssertTrue(waitUntilHittable(option("4:3", in: second)))
        tap(option("4:3", in: second))
        XCTAssertTrue(waitUntilSelected(option("4:3", in: second)))
        tap(element(FlowElement.subPanelBack, in: second))
        let secondFlash = element(FlowElement.flash, in: second)
        XCTAssertTrue(waitUntilHittable(secondFlash))
        tap(secondFlash)
        XCTAssertTrue(waitForValue("Off", of: secondFlash))
        tap(secondFlash)
        XCTAssertTrue(waitForValue("Automatic", of: secondFlash))
        second.terminate()

        let third = launchFlow(resetsState: false, appliesStoredPreferences: true)
        XCTAssertTrue(waitForValue("Automatic", of: element(FlowElement.flash, in: third)))
        XCTAssertFalse(element(FlowElement.indicator("aspect"), in: third).exists)
    }

    func testFlowWithoutStoredPreferencesOpensWithTheValuesOfItsArguments() throws {
        let first = launchFlow(["-cameraFlowSubPanel", "timer"])
        XCTAssertTrue(waitUntilHittable(option("5s", in: first)))
        tap(option("5s", in: first))
        XCTAssertTrue(waitUntilSelected(option("5s", in: first)))
        first.terminate()

        let second = launchFlow(["-cameraFlowSubPanel", "timer"], resetsState: false)
        XCTAssertTrue(waitUntilSelected(option("off", in: second)))
        XCTAssertFalse(element(FlowElement.indicator("timer"), in: second).exists)
        second.terminate()

        let third = launchFlow(["-cameraFlowSubPanel", "timer"], resetsState: false, appliesStoredPreferences: true)
        XCTAssertTrue(waitUntilSelected(option("5s", in: third)))
        tap(option("off", in: third))
        XCTAssertTrue(waitUntilSelected(option("off", in: third)))
    }

    // MARK: - Settings the flow remembers

    func testFlowRemembersTheUserSettingsAndForgetsTheExposure() throws {
        let first = launchFlow(["-cameraFlowSubPanel", "flash"], usesMemory: true)
        XCTAssertTrue(waitUntilHittable(option("off", in: first)))
        tap(option("off", in: first))
        XCTAssertTrue(waitUntilSelected(option("off", in: first)))
        tap(element(FlowElement.subPanelBack, in: first))
        chooseOption("1:1", ofTile: "aspect", in: first)
        chooseOption("3s", ofTile: "timer", in: first)
        let exposureTile = element(FlowElement.tile("exposure"), in: first)
        XCTAssertTrue(waitUntilHittable(exposureTile))
        tap(exposureTile)
        let ruler = option("ruler", in: first)
        XCTAssertTrue(waitUntilHittable(ruler))
        let middle = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        middle.press(forDuration: 0.1, thenDragTo: middle.withOffset(CGVector(dx: -80, dy: 0)))
        XCTAssertTrue(element(FlowElement.indicator("exposure"), in: first).waitForExistence(timeout: timeout))
        first.terminate()

        let second = launchFlow(resetsState: false, usesMemory: true)
        XCTAssertTrue(waitForValue("Off", of: element(FlowElement.flash, in: second)))
        XCTAssertTrue(waitForValue("Square", of: element(FlowElement.indicator("aspect"), in: second)))
        XCTAssertTrue(waitForValue("3 seconds", of: element(FlowElement.indicator("timer"), in: second)))
        XCTAssertFalse(element(FlowElement.indicator("exposure"), in: second).exists)
        second.terminate()

        let forgetful = launchFlow(resetsState: false)
        XCTAssertTrue(waitForValue("Automatic", of: element(FlowElement.flash, in: forgetful)))
        XCTAssertFalse(element(FlowElement.indicator("aspect"), in: forgetful).exists)
        XCTAssertFalse(element(FlowElement.indicator("timer"), in: forgetful).exists)
        forgetful.terminate()

        // A flow that forgets leaves the memory as it was for the next flow that remembers.
        let last = launchFlow(["-cameraFlowSubPanel", "flash"], resetsState: false, usesMemory: true)
        XCTAssertTrue(waitUntilSelected(option("off", in: last)))
    }

    /// Opens the sub-panel of a tile of the open control panel, chooses an option and returns to the tiles.
    private func chooseOption(_ name: String, ofTile setting: String, in app: XCUIApplication) {
        let tile = element(FlowElement.tile(setting), in: app)
        XCTAssertTrue(waitUntilHittable(tile))
        tap(tile)
        XCTAssertTrue(waitUntilHittable(option(name, in: app)))
        tap(option(name, in: app))
        XCTAssertTrue(waitUntilSelected(option(name, in: app)))
        tap(element(FlowElement.subPanelBack, in: app))
        XCTAssertTrue(waitUntilHittable(tile))
    }

    // MARK: - Ukrainian

    func testCameraAndItsPanelInUkrainian() throws {
        let app = launchFlow(["-cameraFlowPanel"], language: "uk", region: "UA")
        let names = [
            "flash": "Спалах", "aspect": "Пропорції", "timer": "Таймер", "exposure": "Експозиція",
            "format": "Фотоформат", "dualCamera": "Подвійне захоплення", "librarySave": "Зберегти"
        ]
        XCTAssertTrue(waitUntilHittable(element(FlowElement.tile("flash"), in: app)))

        for (setting, name) in names {
            XCTAssertEqual(element(FlowElement.tile(setting), in: app).label, name)
        }
        // VoiceOver reads the full stock name, the tile shows the short word in capitals.
        XCTAssertTrue(app.staticTexts["ФОРМАТ"].exists)
        XCTAssertEqual(element(FlowElement.shutter, in: app).label, "Зняти")
        XCTAssertEqual(element(FlowElement.modeShooting, in: app).label, "Зйомка")
        XCTAssertEqual(element(FlowElement.modeReview, in: app).label, "Перегляд")
        XCTAssertEqual(element(FlowElement.exit, in: app).label, "Закрити")
    }

    // MARK: - Large text

    func testIntroductionAtTheLargestTextSizeKeepsItsButtonOnScreenAndItsTextInReach() throws {
        let size = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        let app = launchFlow(["-cameraFlowAccess", "camera"] + size)
        let title = element(FlowElement.onboardingTitle, in: app)
        let proceed = element(FlowElement.onboardingContinue, in: app)
        XCTAssertTrue(title.waitForExistence(timeout: timeout))
        attachScreenshot(named: "onboarding-largest-text")

        XCTAssertTrue(waitUntilHittable(proceed))
        XCTAssertTrue(app.frame.contains(proceed.frame))
        XCTAssertGreaterThan(title.frame.height, 60)
        XCTAssertLessThanOrEqual(title.frame.maxX, app.frame.maxX)
        XCTAssertGreaterThanOrEqual(title.frame.minX, app.frame.minX)

        // Only the button stays at the bottom: the footnote scrolls with the rows, after the last one.
        let footnote = app.staticTexts["You’ll be asked for camera access next. You can change it anytime in Settings."]
        let lastRow = app.staticTexts["Check each photo and draw on it before you finish."]
        XCTAssertTrue(footnote.exists)
        XCTAssertTrue(lastRow.exists)
        XCTAssertGreaterThan(footnote.frame.minY, app.frame.height * 0.3, "no room is left for the rows")
        let screenTop = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
        let from = screenTop.withOffset(CGVector(dx: 0, dy: footnote.frame.minY - 40))
        let top = screenTop.withOffset(CGVector(dx: 0, dy: 60))
        for _ in 0..<20 where lastRow.frame.maxY > footnote.frame.minY + 1 {
            from.press(forDuration: 0.05, thenDragTo: top)
        }
        XCTAssertLessThanOrEqual(lastRow.frame.maxY, footnote.frame.minY + 1)

        tap(proceed)

        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
    }
}
