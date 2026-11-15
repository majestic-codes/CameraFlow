//
//  CameraFlowFormatUITests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// The format, Live Photo and saving to the photo library, the top bar with more indicators than fit, and the
/// settings the app fixed.
@MainActor
final class CameraFlowFormatUITests: XCTestCase, CameraFlowDriving {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Format

    func testFormatSubPanelOffersHEIFAndRAWAndRAWShowsItsIndicator() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "format"])
        let indicator = element(FlowElement.indicator("format"), in: app)
        XCTAssertTrue(waitUntilSelected(option("heif", in: app)))
        XCTAssertTrue(option("raw", in: app).isEnabled)
        XCTAssertFalse(indicator.exists)

        tap(option("raw", in: app))

        XCTAssertTrue(waitUntilSelected(option("raw", in: app)))
        XCTAssertFalse(option("heif", in: app).isSelected)
        XCTAssertTrue(waitForValue("RAW", of: indicator))

        tap(option("heif", in: app))

        XCTAssertTrue(waitUntilSelected(option("heif", in: app)))
        XCTAssertTrue(indicator.waitForNonExistence(timeout: timeout))
    }

    func testRAWIsNotOfferedBelowTheHighQualityAndComesBackWithIt() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "format"])
        XCTAssertTrue(waitUntilSelected(option("high", in: app)))
        XCTAssertTrue(option("raw", in: app).isEnabled)

        tap(option("medium", in: app))

        XCTAssertTrue(waitUntilSelected(option("medium", in: app)))
        XCTAssertTrue(waitUntilDisabled(option("raw", in: app)))

        tap(option("high", in: app))

        XCTAssertTrue(waitUntilEnabled(option("raw", in: app)))
    }

    func testLockedFormatHasNoFormatRow() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "format", "-cameraFlowLock", "format"])

        XCTAssertTrue(waitUntilHittable(option("high", in: app)))
        XCTAssertFalse(option("heif", in: app).exists)
        XCTAssertFalse(option("raw", in: app).exists)
    }

    func testOutputThatChangesThePhotosOffersNoRAW() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "format", "-cameraFlowFormat", "jpeg:0.8"])

        XCTAssertTrue(waitUntilHittable(option("heif", in: app)))
        XCTAssertFalse(option("raw", in: app).exists)
    }

    // MARK: - Live Photo

    func testLivePhotoIsNotOfferedByDefault() throws {
        let app = launchFlow(["-cameraFlowPanel"])

        XCTAssertTrue(waitUntilHittable(element(FlowElement.tile("flash"), in: app)))
        XCTAssertFalse(element(FlowElement.tile("live"), in: app).exists)
        XCTAssertFalse(element(FlowElement.live, in: app).exists)
    }

    func testLiveIndicatorSwitchesLivePhotoAndAPhotoIsTaken() throws {
        let app = launchFlow(["-cameraFlowLive"])
        let live = element(FlowElement.live, in: app)
        XCTAssertTrue(waitForValue("Off", of: live))
        XCTAssertTrue(live.isEnabled)

        tap(live)

        XCTAssertTrue(waitForValue("On", of: live))
        takePhoto(in: app, expecting: 1)

        tap(live)

        XCTAssertTrue(waitForValue("Off", of: live))
    }

    func testLivePhotoIsUnavailableOutsideFourByThreeAndComesBackWithIt() throws {
        let app = launchFlow(["-cameraFlowLive", "-cameraFlowSubPanel", "aspect"])
        let live = element(FlowElement.live, in: app)
        XCTAssertTrue(waitUntilEnabled(live))
        tap(live)
        XCTAssertTrue(waitForValue("On", of: live))

        tap(option("16:9", in: app))

        XCTAssertTrue(waitUntilDisabled(live))
        XCTAssertTrue(waitForValue("Off", of: live))

        tap(option("4:3", in: app))

        XCTAssertTrue(waitUntilEnabled(live))
        XCTAssertTrue(waitForValue("On", of: live))
    }

    func testLiveSubPanelIsInertOutsideFourByThree() throws {
        let app = launchFlow(["-cameraFlowLive", "-cameraFlowAspect", "1:1", "-cameraFlowSubPanel", "live"])

        XCTAssertTrue(waitUntilHittable(element(FlowElement.subPanelBack, in: app)))
        XCTAssertTrue(waitUntilDisabled(option("on", in: app)))
        XCTAssertFalse(option("on", in: app).isSelected)
    }

    // MARK: - Saving to the photo library

    private let simulatedLibrary = ["-cameraFlowAccess", "library", "-cameraFlowNoOnboarding"]

    func testSaveIndicatorSwitchesSavingOnAndOff() throws {
        let app = launchFlow(simulatedLibrary)
        let save = element(FlowElement.save, in: app)
        XCTAssertTrue(waitForValue("Off", of: save))

        tap(save)
        XCTAssertTrue(waitForValue("On", of: save))
        XCTAssertFalse(element(FlowElement.notice, in: app).exists)

        tap(save)
        XCTAssertTrue(waitForValue("Off", of: save))
    }

    func testSaveSubPanelSwitchesSavingAndNamesTheLibrary() throws {
        let app = launchFlow(simulatedLibrary + ["-cameraFlowSubPanel", "librarySave"])
        XCTAssertTrue(waitUntilSelected(option("off", in: app)))
        XCTAssertTrue(app.staticTexts["Photo library"].exists)

        tap(option("on", in: app))

        XCTAssertTrue(waitUntilSelected(option("on", in: app)))
        XCTAssertTrue(waitForValue("On", of: element(FlowElement.save, in: app)))
    }

    func testSaveSubPanelNamesTheAlbum() throws {
        let album = ["-cameraFlowSaveToAlbum", "Field trips"]
        let app = launchFlow(simulatedLibrary + ["-cameraFlowSubPanel", "librarySave"], saving: album)

        XCTAssertTrue(waitUntilSelected(option("on", in: app)))
        XCTAssertTrue(app.staticTexts["Album “Field trips”"].exists)
    }

    func testLockedSavingHasNoSwitch() throws {
        let arguments = ["-cameraFlowLock", "save", "-cameraFlowPanel"]
        let app = launchFlow(simulatedLibrary + arguments, saving: ["-cameraFlowSaveToLibrary"])

        XCTAssertTrue(waitUntilHittable(element(FlowElement.tile("flash"), in: app)))
        XCTAssertFalse(element(FlowElement.tile("librarySave"), in: app).exists)
        XCTAssertFalse(element(FlowElement.save, in: app).exists)
    }

    // MARK: - Top bar

    func testTopBarWithMoreIndicatorsThanFitScrollsToTheLastOne() throws {
        let arguments = [
            "-cameraFlowLive", "-cameraFlowAspect", "1:1", "-cameraFlowTimer", "3", "-cameraFlowExposure", "0.7",
            "-cameraFlowQuality", "low"
        ]
        let app = launchFlow(arguments)
        let flash = element(FlowElement.flash, in: app)
        let format = element(FlowElement.indicator("format"), in: app)
        let flip = element(FlowElement.flip, in: app)
        XCTAssertTrue(flash.waitForExistence(timeout: timeout))
        let identifiers = [
            FlowElement.flash, FlowElement.live, FlowElement.dualCamera, FlowElement.save,
            FlowElement.indicator("aspect"), FlowElement.indicator("timer"), FlowElement.indicator("exposure"),
            FlowElement.indicator("format")
        ]
        for identifier in identifiers {
            XCTAssertTrue(element(identifier, in: app).exists, "no indicator \(identifier)")
        }
        XCTAssertTrue(waitUntilHittable(flash))
        // The wider column of an iPad fits the whole row, so only a phone has to scroll to the last indicator.
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertTrue(format.isHittable)
        } else {
            XCTAssertFalse(format.isHittable)
            let row = flash.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            row.press(forDuration: 0.05, thenDragTo: row.withOffset(CGVector(dx: -200, dy: 0)))
        }

        XCTAssertTrue(waitUntilHittable(format))
        XCTAssertLessThanOrEqual(format.frame.maxX, flip.frame.minX + 1)
        XCTAssertTrue(flip.isHittable)

        tap(format)

        XCTAssertTrue(waitUntilSelected(option("low", in: app)))
    }

    func testNewIndicatorOfAFullTopBarIsBroughtIntoView() throws {
        let arguments = [
            "-cameraFlowLive", "-cameraFlowAspect", "1:1", "-cameraFlowTimer", "3", "-cameraFlowExposure", "0.7",
            "-cameraFlowSubPanel", "format"
        ]
        let app = launchFlow(arguments)
        let format = element(FlowElement.indicator("format"), in: app)
        XCTAssertTrue(waitUntilSelected(option("high", in: app)))
        XCTAssertFalse(format.exists)

        tap(option("low", in: app))

        XCTAssertTrue(waitUntilHittable(format))
        XCTAssertLessThanOrEqual(format.frame.maxX, element(FlowElement.flip, in: app).frame.minX + 1)
    }

    // MARK: - Settings the app fixed

    func testFlowWithEverySettingFixedHasNoPanelAndNoIndicator() throws {
        let locked = "flash,aspect,timer,exposure,format,dual,save,quality"
        let app = launchFlow(["-cameraFlowLock", locked])

        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
        XCTAssertFalse(element(FlowElement.more, in: app).exists)
        XCTAssertFalse(element(FlowElement.flash, in: app).exists)
        XCTAssertFalse(element(FlowElement.dualCamera, in: app).exists)
        XCTAssertFalse(element(FlowElement.save, in: app).exists)
        XCTAssertTrue(element(FlowElement.flip, in: app).isHittable)
        takePhoto(in: app, expecting: 1)
    }

    func testFixedSettingsHaveNoTileAndKeepTheirValues() throws {
        let arguments = [
            "-cameraFlowAspect", "16:9", "-cameraFlowTimer", "3", "-cameraFlowLock", "flash,aspect,timer",
            "-cameraFlowPanel"
        ]
        let app = launchFlow(arguments)
        XCTAssertTrue(waitUntilHittable(element(FlowElement.tile("exposure"), in: app)))

        for setting in ["flash", "aspect", "timer"] {
            XCTAssertFalse(element(FlowElement.tile(setting), in: app).exists, "a fixed setting has a tile: \(setting)")
        }
        XCTAssertFalse(element(FlowElement.flash, in: app).exists)
        let viewfinder = element(FlowElement.viewfinder, in: app)
        XCTAssertEqual(viewfinder.frame.height / viewfinder.frame.width, 16.0 / 9.0, accuracy: 0.01)
    }
}
