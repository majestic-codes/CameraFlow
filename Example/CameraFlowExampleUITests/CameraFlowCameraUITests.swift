//
//  CameraFlowCameraUITests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// The shooting mode of the camera flow: the shutter and the count, the zoom, the two cameras, the camera that
/// does not start and the elements that stay upright.
@MainActor
final class CameraFlowCameraUITests: XCTestCase, CameraFlowDriving {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Shutter and count

    func testShutterTakesPhotosAndTheBadgeCountsThem() throws {
        let app = launchFlow()
        let badge = element(FlowElement.badge, in: app)
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
        XCTAssertFalse(badge.exists)
        XCTAssertFalse(element(FlowElement.modeReview, in: app).isEnabled)
        XCTAssertFalse(element(FlowElement.accept, in: app).isEnabled)

        takePhoto(in: app, expecting: 1)
        takePhoto(in: app, expecting: 2)

        XCTAssertTrue(waitUntilEnabled(element(FlowElement.modeReview, in: app)))
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.accept, in: app)))
        XCTAssertEqual(badge.label, "Photos in the set")
    }

    func testFullSetDisablesTheShutterAndTheLibrary() throws {
        let app = launchFlow(["-cameraFlowLimit", "2"])
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.library, in: app)))

        takePhoto(in: app, expecting: 1)
        XCTAssertTrue(element(FlowElement.shutter, in: app).isEnabled)
        takePhoto(in: app, expecting: 2)

        XCTAssertTrue(waitUntilDisabled(element(FlowElement.shutter, in: app)))
        XCTAssertTrue(waitUntilDisabled(element(FlowElement.library, in: app)))
        XCTAssertTrue(element(FlowElement.accept, in: app).isEnabled)
        XCTAssertEqual(element(FlowElement.badge, in: app).value as? String, "2")
    }

    func testDeletingAPhotoOfAFullSetGivesTheShutterBack() throws {
        let app = launchFlow(["-cameraFlowLimit", "1"])
        takePhoto(in: app, expecting: 1)
        XCTAssertTrue(waitUntilDisabled(element(FlowElement.shutter, in: app)))
        openReview(in: app)
        XCTAssertFalse(element(FlowElement.reviewAdd, in: app).isEnabled)

        tap(element(FlowElement.reviewDelete, in: app))
        let delete = app.sheets.buttons["Delete photo"]
        XCTAssertTrue(delete.waitForExistence(timeout: timeout))
        tap(delete)

        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
        XCTAssertTrue(element(FlowElement.badge, in: app).waitForNonExistence(timeout: timeout))
    }

    // MARK: - Zoom

    func testLensButtonsSelectTheirZoom() throws {
        let app = launchFlow()
        let one = element(FlowElement.lens("1"), in: app)
        let two = element(FlowElement.lens("2"), in: app)
        let half = element(FlowElement.lens("0.5"), in: app)
        XCTAssertTrue(waitUntilSelected(one))
        for factor in ["0.5", "1", "2", "4", "8"] {
            XCTAssertTrue(element(FlowElement.lens(factor), in: app).exists, "no lens button \(factor)")
        }

        tapMiddle(of: two)
        XCTAssertTrue(waitUntilSelected(two))
        XCTAssertFalse(one.isSelected)
        XCTAssertTrue(waitForValue("2 times", of: element(FlowElement.zoomDial, in: app)))

        tapMiddle(of: half)
        XCTAssertTrue(waitUntilSelected(half))
        XCTAssertFalse(two.isSelected)
    }

    func testHoldingTheLensRowOpensTheDialAndADragTurnsIt() throws {
        let app = launchFlow()
        let dial = element(FlowElement.zoomDial, in: app)
        let one = element(FlowElement.lens("1"), in: app)
        XCTAssertTrue(waitUntilSelected(one))
        XCTAssertEqual(dial.value as? String, "1 times")
        let viewfinder = element(FlowElement.viewfinder, in: app)
        let closedWidth = dial.frame.width
        XCTAssertLessThan(closedWidth, viewfinder.frame.width - 50)

        let start = one.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: -120, dy: 0))
        start.press(forDuration: 1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.5)

        XCTAssertTrue(wait(for: dial, until: "value != '1 times'"))
        XCTAssertFalse(one.isSelected)
        // The dial is the whole strip across the viewfinder while it is open, and the lens row again once it closed.
        let closed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in dial.frame.width < viewfinder.frame.width - 50 },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: timeout), .completed)
    }

    func testOpenDialSpansTheViewfinderTurnsUnderADragAndClosesAfterIt() throws {
        let app = launchFlow(["-cameraFlowDial"])
        let dial = element(FlowElement.zoomDial, in: app)
        let viewfinder = element(FlowElement.viewfinder, in: app)
        // The viewfinder spans the screen of a phone and the column of the camera on an iPad.
        let opened = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in dial.exists && dial.frame.width >= viewfinder.frame.width - 1 },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [opened], timeout: timeout), .completed)
        XCTAssertEqual(dial.value as? String, "1 times")
        XCTAssertTrue(viewfinder.frame.insetBy(dx: -1, dy: -1).contains(dial.frame))

        let start = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        let end = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)

        XCTAssertTrue(wait(for: dial, until: "value != '1 times'"))
        let closed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in dial.frame.width < viewfinder.frame.width - 50 },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: timeout), .completed)
    }

    // MARK: - Front and back camera

    func testFlipSwitchesToTheFrontCameraAndBack() throws {
        let app = launchFlow()
        let wide = element(FlowElement.lens("0.5"), in: app)
        XCTAssertTrue(wide.waitForExistence(timeout: timeout))
        XCTAssertTrue(element(FlowElement.lens("8"), in: app).exists)

        tap(element(FlowElement.flip, in: app))

        XCTAssertTrue(wide.waitForNonExistence(timeout: timeout))
        XCTAssertFalse(element(FlowElement.lens("8"), in: app).exists)
        XCTAssertTrue(waitUntilSelected(element(FlowElement.lens("1"), in: app)))
        takePhoto(in: app, expecting: 1)

        tap(element(FlowElement.flip, in: app))

        XCTAssertTrue(wide.waitForExistence(timeout: timeout))
        XCTAssertTrue(waitUntilSelected(element(FlowElement.lens("1"), in: app)))
        takePhoto(in: app, expecting: 2)
    }

    // MARK: - Second camera's circle

    func testCircleSwitchesOnAndOffFromTheTopBar() throws {
        let app = launchFlow()
        let indicator = element(FlowElement.dualCamera, in: app)
        let circle = element(FlowElement.dualCameraCircle, in: app)
        XCTAssertTrue(waitForValue("Off", of: indicator))
        XCTAssertFalse(circle.exists)

        tap(indicator)

        XCTAssertTrue(waitForValue("On", of: indicator))
        XCTAssertTrue(circle.waitForExistence(timeout: timeout))
        XCTAssertEqual(circle.label, "Front camera")
        XCTAssertTrue(element(FlowElement.viewfinder, in: app).frame.contains(circle.frame))
        takePhoto(in: app, expecting: 1)

        tap(indicator)

        XCTAssertTrue(waitForValue("Off", of: indicator))
        XCTAssertTrue(circle.waitForNonExistence(timeout: timeout))
    }

    func testFlipSwapsTheCamerasOfTheCircle() throws {
        let app = launchFlow(["-cameraFlowDualCamera"])
        let circle = element(FlowElement.dualCameraCircle, in: app)
        XCTAssertTrue(circle.waitForExistence(timeout: timeout))
        XCTAssertEqual(circle.label, "Front camera")

        tap(element(FlowElement.flip, in: app))

        XCTAssertTrue(waitForLabel("Back camera", of: circle))
        XCTAssertEqual(element(FlowElement.dualCamera, in: app).value as? String, "On")

        tap(element(FlowElement.flip, in: app))

        XCTAssertTrue(waitForLabel("Front camera", of: circle))
    }

    func testSwappedArgumentOpensWithTheBackCameraInTheCircle() throws {
        let app = launchFlow(["-cameraFlowDualCameraSwapped"])
        let circle = element(FlowElement.dualCameraCircle, in: app)

        XCTAssertTrue(circle.waitForExistence(timeout: timeout))
        XCTAssertEqual(circle.label, "Back camera")
    }

    func testCircleSwitchesFromItsSubPanel() throws {
        let app = launchFlow(["-cameraFlowSubPanel", "dualCamera"])
        XCTAssertTrue(waitUntilSelected(option("off", in: app)))
        XCTAssertEqual(element(FlowElement.subPanelTitle, in: app).label, "Dual Capture")

        tap(option("on", in: app))

        XCTAssertTrue(waitUntilSelected(option("on", in: app)))
        XCTAssertTrue(element(FlowElement.dualCameraCircle, in: app).waitForExistence(timeout: timeout))

        tap(option("off", in: app))

        XCTAssertTrue(waitUntilSelected(option("off", in: app)))
        XCTAssertTrue(element(FlowElement.dualCameraCircle, in: app).waitForNonExistence(timeout: timeout))
    }

    // MARK: - Focus

    func testTapOnTheViewfinderShowsTheFocusReticleThere() throws {
        let app = launchFlow()
        let viewfinder = element(FlowElement.viewfinder, in: app)
        let reticle = element(FlowElement.focusReticle, in: app)
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
        XCTAssertFalse(reticle.exists)

        let point = viewfinder.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
        point.tap()

        XCTAssertTrue(reticle.waitForExistence(timeout: timeout))
        XCTAssertEqual(reticle.frame.midX, point.screenPoint.x, accuracy: 3)
        XCTAssertEqual(reticle.frame.midY, point.screenPoint.y, accuracy: 3)
        XCTAssertTrue(reticle.waitForNonExistence(timeout: timeout))
    }

    // MARK: - A camera that does not start

    func testCameraThatFailsToStartOffersAnotherTryWhichStartsIt() throws {
        let app = launchFlow(["-cameraFlowStartFailures", "1"])
        let retry = element(FlowElement.retry, in: app)
        let shutter = element(FlowElement.shutter, in: app)
        XCTAssertTrue(retry.waitForExistence(timeout: timeout))
        XCTAssertEqual(retry.label, "Try Again")
        XCTAssertTrue(app.staticTexts["Camera unavailable"].exists)
        XCTAssertFalse(shutter.isEnabled)
        XCTAssertFalse(element(FlowElement.openSettings, in: app).exists)
        XCTAssertTrue(element(FlowElement.exit, in: app).isHittable)

        tap(retry)

        XCTAssertTrue(retry.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilEnabled(shutter))
        takePhoto(in: app, expecting: 1)
    }

    func testCameraThatKeepsFailingKeepsOfferingAnotherTry() throws {
        let app = launchFlow(["-cameraFlowStartFailures", "2"])
        let retry = element(FlowElement.retry, in: app)
        XCTAssertTrue(retry.waitForExistence(timeout: timeout))

        tap(retry)

        XCTAssertTrue(retry.waitForExistence(timeout: timeout))
        XCTAssertFalse(element(FlowElement.shutter, in: app).isEnabled)

        tap(retry)

        XCTAssertTrue(retry.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilEnabled(element(FlowElement.shutter, in: app)))
    }

    func testFailureInUkrainian() throws {
        let app = launchFlow(["-cameraFlowStartFailures", "1"], language: "uk", region: "UA")
        let retry = element(FlowElement.retry, in: app)

        XCTAssertTrue(retry.waitForExistence(timeout: timeout))
        XCTAssertEqual(retry.label, "Спробувати ще раз")
        XCTAssertTrue(app.staticTexts["Камера недоступна"].exists)
    }

    // MARK: - Elements that stay upright

    func testCountdownDigitTurnsWithThePhone() throws {
        let upright = try countdownFrame(rotation: nil)
        XCTAssertGreaterThan(upright.height, upright.width)

        for rotation in ["left", "right"] {
            let turned = try countdownFrame(rotation: rotation)
            XCTAssertGreaterThan(turned.width, turned.height, "the digit is not on its side at \(rotation)")
            XCTAssertEqual(turned.midX, upright.midX, accuracy: 3)
            XCTAssertEqual(turned.midY, upright.midY, accuracy: 3)
        }

        // The digit grows in as it appears, so its size is not compared, only the way it lies.
        let upsideDown = try countdownFrame(rotation: "down")
        XCTAssertGreaterThan(upsideDown.height, upsideDown.width)
        XCTAssertEqual(upsideDown.midX, upright.midX, accuracy: 3)
        XCTAssertEqual(upsideDown.midY, upright.midY, accuracy: 3)
    }

    /// The frame of the digit of the self-timer in a flow whose simulated phone is held the given way.
    private func countdownFrame(rotation: String?) throws -> CGRect {
        let rotationArguments = rotation.map { ["-cameraFlowRotation", $0] } ?? []
        let app = launchFlow(["-cameraFlowTimer", "5"] + rotationArguments)
        let shutter = element(FlowElement.shutter, in: app)
        XCTAssertTrue(waitUntilEnabled(shutter))
        tap(shutter)
        let countdown = element(FlowElement.countdown, in: app)
        XCTAssertTrue(countdown.waitForExistence(timeout: timeout))
        let frame = countdown.frame
        tap(shutter)
        XCTAssertTrue(countdown.waitForNonExistence(timeout: timeout))
        app.terminate()
        return frame
    }
}
