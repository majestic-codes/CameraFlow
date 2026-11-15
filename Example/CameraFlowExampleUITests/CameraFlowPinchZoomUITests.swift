//
//  CameraFlowPinchZoomUITests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// The pinch on the viewfinder of the camera flow, over the simulated camera.
@MainActor
final class CameraFlowPinchZoomUITests: XCTestCase, CameraFlowDriving {
    /// The lens buttons of the simulated back camera: the factor as their identifiers write it, and its zoom.
    private let lensFactors: [String: Double] = ["0.5": 0.5, "1": 1, "2": 2, "4": 4, "8": 8]

    override func setUp() {
        continueAfterFailure = false
    }

    /// The lens button that is selected is the one that writes the current zoom. The row is hidden while the dial
    /// the pinch opened is still up, so each reading waits for the row to come back.
    func testPinchOutZoomsInAndPinchInZoomsBackTowardsTheMainLens() throws {
        let app = launchFlow()
        let viewfinder = element(FlowElement.viewfinder, in: app)
        XCTAssertTrue(viewfinder.waitForExistence(timeout: timeout))
        XCTAssertEqual(try selectedLensFactor(in: app), 1)

        viewfinder.pinch(withScale: 4, velocity: 4)

        let zoomedIn = try selectedLensFactor(in: app)
        XCTAssertGreaterThan(zoomedIn, 1, "a pinch out did not zoom in")

        viewfinder.pinch(withScale: 0.25, velocity: -4)

        let zoomedBack = try selectedLensFactor(in: app)
        XCTAssertLessThan(zoomedBack, zoomedIn, "a pinch in did not zoom back")
        XCTAssertLessThanOrEqual(zoomedBack, 2, "a pinch in did not come back towards the main lens")
    }

    /// The factor of the selected lens button, once the dial has closed and the lens row shows again. The dial is
    /// the whole strip across the viewfinder while it is open, and the lens row again once it closed. The viewfinder
    /// spans the screen of a phone and the column of the camera on an iPad.
    private func selectedLensFactor(in app: XCUIApplication) throws -> Double {
        let dial = element(FlowElement.zoomDial, in: app)
        let viewfinder = element(FlowElement.viewfinder, in: app)
        let closed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in dial.exists && dial.frame.width < viewfinder.frame.width - 50 },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: timeout), .completed, "the dial did not close")
        let selected = lensFactors.first { name, _ in
            let lens = element(FlowElement.lens(name), in: app)
            return lens.exists && lens.isSelected
        }
        return try XCTUnwrap(selected, "no lens button is selected").value
    }
}
