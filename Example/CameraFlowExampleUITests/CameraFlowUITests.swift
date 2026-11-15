//
//  CameraFlowUITests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// The quality row of the Format sub-panel, the indicators of changed settings in the top bar, the place of the zoom
/// dial at every aspect ratio and the values the user changes.
@MainActor
final class CameraFlowUITests: XCTestCase, CameraFlowDriving {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Format sub-panel: quality row

    func testQualityRowOffersThreeQualitiesWithHighSelectedAndTheSizeOfAPhoto() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "format"])

        XCTAssertTrue(waitUntilSelected(option("high", in: app)))
        XCTAssertTrue(option("medium", in: app).exists)
        XCTAssertTrue(option("low", in: app).exists)
        XCTAssertTrue(app.staticTexts["QUALITY"].exists)
        let size = element(FlowElement.photoSize, in: app)
        XCTAssertTrue(size.waitForExistence(timeout: timeout))
        XCTAssertTrue(size.label.hasPrefix("About "), size.label)
        XCTAssertTrue(size.label.hasSuffix(" per photo."), size.label)
        XCTAssertFalse(element(FlowElement.indicator("format"), in: app).exists)
    }

    func testChoosingLowQualityChangesTheSizeAndShowsTheFormatIndicator() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "format"])
        let size = element(FlowElement.photoSize, in: app)
        let indicator = element(FlowElement.indicator("format"), in: app)
        XCTAssertTrue(waitUntilSelected(option("high", in: app)))
        XCTAssertTrue(size.waitForExistence(timeout: timeout))
        let sizeAtHigh = size.label

        tap(option("low", in: app))

        XCTAssertTrue(waitUntilSelected(option("low", in: app)))
        XCTAssertFalse(option("high", in: app).isSelected)
        XCTAssertTrue(waitForLabel(of: size, toChangeFrom: sizeAtHigh))
        tap(element(FlowElement.subPanelBack, in: app))
        XCTAssertTrue(waitForValue("Low", of: indicator))

        tap(indicator)
        tap(option("high", in: app))
        XCTAssertTrue(waitUntilSelected(option("high", in: app)))
        XCTAssertTrue(waitForLabel(sizeAtHigh, of: size))
        tap(element(FlowElement.subPanelBack, in: app))
        XCTAssertTrue(indicator.waitForNonExistence(timeout: timeout))
    }

    func testQualityArgumentOpensWithThatQualityAndItsIndicator() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "format", "-cameraFlowQuality", "medium"])

        XCTAssertTrue(waitUntilSelected(option("medium", in: app)))
        XCTAssertTrue(waitForValue("Medium", of: element(FlowElement.indicator("format"), in: app)))
    }

    func testLockedQualityHasNoRowAndNoSize() throws {
        let arguments = ["-cameraFlowSubPanel", "format", "-cameraFlowQuality", "low", "-cameraFlowLock", "quality"]
        let app = launchFlow(arguments)

        XCTAssertTrue(waitUntilHittable(element(FlowElement.subPanelBack, in: app)))
        XCTAssertFalse(option("high", in: app).exists)
        XCTAssertFalse(option("low", in: app).exists)
        XCTAssertFalse(element(FlowElement.photoSize, in: app).exists)
        XCTAssertFalse(element(FlowElement.indicator("format"), in: app).exists)
    }

    func testQualityRowAndSizeInUkrainian() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "format"], language: "uk", region: "UA")

        XCTAssertTrue(waitForLabel("Висока", of: option("high", in: app)))
        XCTAssertEqual(option("medium", in: app).label, "Середня")
        XCTAssertEqual(option("low", in: app).label, "Низька")
        XCTAssertTrue(app.staticTexts["ЯКІСТЬ"].exists)
        let size = element(FlowElement.photoSize, in: app)
        XCTAssertTrue(size.waitForExistence(timeout: timeout))
        XCTAssertTrue(size.label.hasPrefix("Приблизно "), size.label)
        XCTAssertTrue(size.label.hasSuffix(" на фото."), size.label)
    }

    func testChosenQualityComesBackWithTheStoredPreferences() throws {
        let first = launchFlow(["-cameraFlowSubPanel", "format"])
        tap(option("medium", in: first))
        XCTAssertTrue(waitUntilSelected(option("medium", in: first)))
        first.terminate()

        let arguments = ["-cameraFlowSubPanel", "format"]
        let second = launchFlow(arguments, resetsState: false, appliesStoredPreferences: true)
        XCTAssertTrue(waitUntilSelected(option("medium", in: second)))

        tap(option("high", in: second))
        XCTAssertTrue(waitUntilSelected(option("high", in: second)))
    }

    // MARK: - Top bar indicators

    func testIndicatorsOfChangedSettingsSitAfterLiveAndClearOfFlip() throws {
        let app = launchFlow(["-cameraFlowAspect", "16:9", "-cameraFlowTimer", "3", "-cameraFlowExposure", "0.7"])
        let flash = element(FlowElement.flash, in: app)
        let aspect = element(FlowElement.indicator("aspect"), in: app)
        let timer = element(FlowElement.indicator("timer"), in: app)
        let exposure = element(FlowElement.indicator("exposure"), in: app)
        let flip = element(FlowElement.flip, in: app)
        for control in [flash, aspect, timer, exposure, flip] {
            XCTAssertTrue(waitUntilHittable(control), "not shown: \(control)")
        }

        XCTAssertGreaterThan(aspect.frame.minX, flash.frame.minX)
        XCTAssertLessThan(aspect.frame.minX, timer.frame.minX)
        XCTAssertLessThan(timer.frame.minX, exposure.frame.minX)
        XCTAssertLessThanOrEqual(exposure.frame.maxX, flip.frame.minX)
        XCTAssertTrue(app.frame.contains(exposure.frame))
    }

    func testDefaultSettingsShowNoChangedIndicator() throws {
        let app = launchFlow()

        XCTAssertTrue(waitUntilHittable(element(FlowElement.flash, in: app)))
        XCTAssertFalse(element(FlowElement.indicator("aspect"), in: app).exists)
        XCTAssertFalse(element(FlowElement.indicator("timer"), in: app).exists)
        XCTAssertFalse(element(FlowElement.indicator("exposure"), in: app).exists)
        XCTAssertFalse(element(FlowElement.indicator("format"), in: app).exists)
    }

    func testAspectIndicatorOpensAspectSubPanel() throws {
        let app = launchFlow(["-cameraFlowAspect", "16:9"])

        tap(element(FlowElement.indicator("aspect"), in: app))

        XCTAssertTrue(waitUntilSelected(option("16:9", in: app)))
        XCTAssertTrue(option("4:3", in: app).exists)
        XCTAssertTrue(option("1:1", in: app).exists)

        tap(element(FlowElement.subPanelBack, in: app))

        XCTAssertTrue(element(FlowElement.subPanel, in: app).waitForNonExistence(timeout: timeout))
    }

    func testTimerIndicatorOpensTimerSubPanel() throws {
        let app = launchFlow(["-cameraFlowTimer", "3"])

        tap(element(FlowElement.indicator("timer"), in: app))

        XCTAssertTrue(waitUntilSelected(option("3s", in: app)))
    }

    // MARK: - Zoom dial

    /// The lens row stands where the 4:3 viewfinder puts it, the one the controls are arranged around: inside it and
    /// centred in it at 4:3, and in the same place at 16:9 and at 1:1, whose viewfinders are taller or shorter. A
    /// sub-panel lifts it in every aspect ratio alike.
    func testZoomDialSitsInTheFourByThreeViewfinderAndKeepsItsPlaceAtEveryAspect() throws {
        for panel in [[String](), ["-cameraFlowSubPanel", "format"]] {
            let app = launchFlow(["-cameraFlowAspect", "4:3"] + panel)
            let dial = element(FlowElement.zoomDial, in: app)
            let viewfinder = element(FlowElement.viewfinder, in: app)
            XCTAssertTrue(waitUntil(dial, liesWithin: viewfinder), "dial outside the viewfinder with \(panel)")
            XCTAssertEqual(dial.frame.midX, viewfinder.frame.midX, accuracy: 2, "dial not centred with \(panel)")
            let place = dial.frame
            app.terminate()

            for aspect in ["16:9", "1:1"] {
                let other = launchFlow(["-cameraFlowAspect", aspect] + panel)
                let otherDial = element(FlowElement.zoomDial, in: other)
                XCTAssertTrue(waitUntil(otherDial, liesAt: place), "dial moved at \(aspect) with \(panel)")
                other.terminate()
            }
        }
    }

    /// Waits for an element to lie inside another one, within a point.
    private func waitUntil(_ element: XCUIElement, liesWithin container: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                element.exists && container.exists && container.frame.insetBy(dx: -1, dy: -1).contains(element.frame)
            },
            object: nil
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits for an element to lie in the given frame, within a point on every side.
    private func waitUntil(_ element: XCUIElement, liesAt frame: CGRect) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                guard element.exists else { return false }
                let current = element.frame
                let liesInside = frame.insetBy(dx: -1, dy: -1).contains(current)
                let coversIt = current.insetBy(dx: -1, dy: -1).contains(frame)
                return liesInside && coversIt
            },
            object: nil
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    // MARK: - Controls and smoke

    func testExitAndModeSwitchExistInCameraMode() throws {
        let app = launchFlow()

        XCTAssertTrue(waitUntilHittable(element(FlowElement.exit, in: app)))
        XCTAssertTrue(element(FlowElement.modeReview, in: app).exists)
    }

    func testAutoCaptureReachesReview() throws {
        let app = launchFlow(["-cameraFlowAutoCapture", "2", "-cameraFlowLimit", "3"])

        XCTAssertTrue(waitForValue("2", of: element(FlowElement.badge, in: app), timeout: 30))
        openReview(in: app)
        XCTAssertTrue(waitForValue("2 of 2", of: element(FlowElement.reviewCounter, in: app)))
    }

    // MARK: - Changing values

    func testChoosingSixteenByNineShowsAspectIndicatorAndFourByThreeHidesIt() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "aspect"])
        let indicator = element(FlowElement.indicator("aspect"), in: app)
        XCTAssertTrue(waitUntilSelected(option("4:3", in: app)))
        XCTAssertFalse(indicator.exists)

        tap(option("16:9", in: app))
        XCTAssertTrue(waitUntilSelected(option("16:9", in: app)))
        tap(element(FlowElement.subPanelBack, in: app))
        XCTAssertTrue(waitForValue("16 by 9", of: indicator))

        tap(indicator)
        tap(option("4:3", in: app))
        XCTAssertTrue(waitUntilSelected(option("4:3", in: app)))
        tap(element(FlowElement.subPanelBack, in: app))
        XCTAssertTrue(indicator.waitForNonExistence(timeout: timeout))
    }

    func testChoosingLiveOnShowsLiveIndicatorAsOn() throws {
        let app = launchFlow(["-cameraFlowLive", "-cameraFlowSubPanel", "live"])
        XCTAssertTrue(waitUntilSelected(option("off", in: app)))

        tap(option("on", in: app))

        XCTAssertTrue(waitUntilSelected(option("on", in: app)))
        tap(element(FlowElement.subPanelBack, in: app))
        XCTAssertTrue(waitForValue("On", of: element(FlowElement.live, in: app)))
    }
}
