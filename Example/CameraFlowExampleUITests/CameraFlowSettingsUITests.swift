//
//  CameraFlowSettingsUITests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// The settings of the camera on the control panel: its tiles, and the sub-panels of the flash, the aspect ratio,
/// the timer and the exposure.
@MainActor
final class CameraFlowSettingsUITests: XCTestCase, CameraFlowDriving {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Control panel

    func testMoreOpensThePanelWithATileForEverySettingAndTheGrabberClosesIt() throws {
        let app = launchFlow(["-cameraFlowLive"])
        let more = element(FlowElement.more, in: app)
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
        XCTAssertFalse(element(FlowElement.panel, in: app).exists)

        tap(more)

        let tiles = ["flash", "live", "aspect", "timer", "exposure", "format", "dualCamera", "librarySave"]
        for setting in tiles {
            let tile = element(FlowElement.tile(setting), in: app)
            XCTAssertTrue(tile.waitForExistence(timeout: timeout), "no tile \(setting)")
        }
        XCTAssertEqual(element(FlowElement.tile("aspect"), in: app).value as? String, "4 by 3")
        XCTAssertEqual(element(FlowElement.tile("format"), in: app).value as? String, "HEIF")

        let panel = element(FlowElement.panel, in: app)
        let top = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
        let grabber = top.withOffset(CGVector(dx: 0, dy: 12))
        grabber.press(forDuration: 0.1, thenDragTo: grabber.withOffset(CGVector(dx: 0, dy: 260)))

        XCTAssertTrue(element(FlowElement.tile("flash"), in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(panel.waitForNonExistence(timeout: timeout))
        takePhoto(in: app, expecting: 1)

        tap(more)

        XCTAssertTrue(element(FlowElement.tile("flash"), in: app).waitForExistence(timeout: timeout))
    }

    func testTileOpensItsSubPanelAndBackReturnsToTheTiles() throws {
        let app = launchFlow(["-cameraFlowPanel"])
        let timerTile = element(FlowElement.tile("timer"), in: app)
        XCTAssertTrue(waitUntilHittable(timerTile))

        tap(timerTile)

        XCTAssertTrue(waitUntilHittable(option("3s", in: app)))
        XCTAssertEqual(element(FlowElement.subPanel, in: app).label, "Timer")
        XCTAssertEqual(element(FlowElement.subPanelTitle, in: app).label, "Timer")

        tap(element(FlowElement.subPanelBack, in: app))

        XCTAssertTrue(waitUntilHittable(timerTile))
        XCTAssertTrue(waitUntilNotHittable(option("3s", in: app)))
    }

    // MARK: - Flash

    func testFlashIndicatorCyclesThroughItsModes() throws {
        let app = launchFlow()
        let flash = element(FlowElement.flash, in: app)
        XCTAssertTrue(waitForValue("Automatic", of: flash))

        tap(flash)
        XCTAssertTrue(waitForValue("On", of: flash))
        tap(flash)
        XCTAssertTrue(waitForValue("Off", of: flash))
        tap(flash)
        XCTAssertTrue(waitForValue("Automatic", of: flash))
    }

    func testFlashSubPanelSelectsEachMode() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "flash"])
        let flash = element(FlowElement.flash, in: app)
        XCTAssertTrue(waitUntilSelected(option("auto", in: app)))

        tap(option("on", in: app))
        XCTAssertTrue(waitUntilSelected(option("on", in: app)))
        XCTAssertFalse(option("auto", in: app).isSelected)
        XCTAssertTrue(waitForValue("On", of: flash))

        tap(option("off", in: app))
        XCTAssertTrue(waitUntilSelected(option("off", in: app)))
        XCTAssertTrue(waitForValue("Off", of: flash))

        tap(option("auto", in: app))
        XCTAssertTrue(waitUntilSelected(option("auto", in: app)))
        XCTAssertTrue(waitForValue("Automatic", of: flash))
    }

    // MARK: - Aspect ratio

    func testAspectRatioShapesTheViewfinder() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "aspect"])
        let viewfinder = element(FlowElement.viewfinder, in: app)
        XCTAssertTrue(waitUntilSelected(option("4:3", in: app)))
        XCTAssertEqual(viewfinder.frame.height / viewfinder.frame.width, 4.0 / 3.0, accuracy: 0.01)

        tap(option("1:1", in: app))
        XCTAssertTrue(waitUntilSelected(option("1:1", in: app)))
        XCTAssertTrue(waitForRatio(1, of: viewfinder))

        tap(option("16:9", in: app))
        XCTAssertTrue(waitUntilSelected(option("16:9", in: app)))
        XCTAssertTrue(waitForRatio(16.0 / 9.0, of: viewfinder))
        XCTAssertEqual(element(FlowElement.indicator("aspect"), in: app).value as? String, "16 by 9")
    }

    func testPhotoTakenInASquareViewfinderIsCounted() throws {
        let app = launchFlow(["-cameraFlowAspect", "1:1"])

        takePhoto(in: app, expecting: 1)

        XCTAssertTrue(waitForRatio(1, of: element(FlowElement.viewfinder, in: app)))
    }

    private func waitForRatio(_ ratio: CGFloat, of viewfinder: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let frame = viewfinder.frame
                return frame.width > 0 && abs(frame.height / frame.width - ratio) < 0.01
            },
            object: nil
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    // MARK: - Timer

    func testTimerSubPanelSelectsEachDelay() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "timer"])
        let indicator = element(FlowElement.indicator("timer"), in: app)
        XCTAssertTrue(waitUntilSelected(option("off", in: app)))
        XCTAssertFalse(indicator.exists)

        for (name, value) in [("3s", "3 seconds"), ("5s", "5 seconds"), ("10s", "10 seconds")] {
            tap(option(name, in: app))
            XCTAssertTrue(waitUntilSelected(option(name, in: app)), "the option \(name) is not selected")
            XCTAssertTrue(waitForValue(value, of: indicator), "the indicator does not say \(value)")
        }

        tap(option("off", in: app))
        XCTAssertTrue(waitUntilSelected(option("off", in: app)))
        XCTAssertTrue(indicator.waitForNonExistence(timeout: timeout))
    }

    func testTimerCountsDownAndTakesThePhoto() throws {
        let app = launchFlow(["-cameraFlowTimer", "3"])
        let shutter = element(FlowElement.shutter, in: app)
        let countdown = element(FlowElement.countdown, in: app)
        XCTAssertTrue(waitUntilEnabled(shutter))
        XCTAssertEqual(shutter.label, "Take picture")

        tap(shutter)

        XCTAssertTrue(countdown.waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForLabel("Stop timer", of: shutter))
        XCTAssertFalse(element(FlowElement.badge, in: app).exists)
        XCTAssertTrue(waitForValue("1", of: element(FlowElement.badge, in: app)))
        XCTAssertTrue(countdown.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitForLabel("Take picture", of: shutter))
    }

    func testShutterStopsTheTimerAndNoPhotoIsTaken() throws {
        let app = launchFlow(["-cameraFlowTimer", "5"])
        let shutter = element(FlowElement.shutter, in: app)
        let countdown = element(FlowElement.countdown, in: app)
        XCTAssertTrue(waitUntilEnabled(shutter))

        tap(shutter)
        XCTAssertTrue(waitForLabel("Stop timer", of: shutter))
        XCTAssertTrue(countdown.waitForExistence(timeout: timeout))
        tap(shutter)

        XCTAssertTrue(countdown.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitForLabel("Take picture", of: shutter))
        // Longer than the timer would have run: the photo it would have taken never comes.
        XCTAssertFalse(element(FlowElement.badge, in: app).waitForExistence(timeout: 6))
        XCTAssertFalse(element(FlowElement.modeReview, in: app).isEnabled)
    }

    // MARK: - Exposure

    func testDraggingTheExposureRulerChangesTheBiasAndShowsItsIndicator() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "exposure"])
        let ruler = option("ruler", in: app)
        let indicator = element(FlowElement.indicator("exposure"), in: app)
        XCTAssertTrue(waitUntilHittable(ruler))
        let neutral = try XCTUnwrap(ruler.value as? String)
        XCTAssertFalse(indicator.exists)

        let start = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -80, dy: 0)))

        XCTAssertTrue(wait(for: ruler, until: "value != '\(neutral)'"))
        XCTAssertTrue(indicator.waitForExistence(timeout: timeout))
        tap(element(FlowElement.subPanelBack, in: app))
        XCTAssertTrue(waitUntilHittable(indicator))

        tap(indicator)

        XCTAssertTrue(waitUntilHittable(ruler))
        XCTAssertNotEqual(ruler.value as? String, neutral)
    }

    func testExposureArgumentOpensWithItsIndicator() throws {
        let app = launchFlow(["-cameraFlowExposure", "1"])
        let indicator = element(FlowElement.indicator("exposure"), in: app)

        XCTAssertTrue(waitUntilHittable(indicator))
        XCTAssertEqual(indicator.label, "Exposure")
        takePhoto(in: app, expecting: 1)
    }
}
