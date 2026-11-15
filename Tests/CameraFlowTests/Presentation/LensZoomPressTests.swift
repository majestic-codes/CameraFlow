//
//  LensZoomPressTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Press on the zoom control")
struct LensZoomPressTests {
    let press = LensZoomPress(start: CGPoint(x: 201, y: 628))

    @Test(
        "A press turns the dial once it travels more than 15 pt sideways or 13 pt up",
        arguments: [
            (201.0, 628.0, false),
            (216.0, 628.0, false),
            (216.5, 628.0, true),
            (185.5, 628.0, true),
            (201.0, 615.0, false),
            (201.0, 614.5, true),
            (201.0, 660.0, false)
        ]
    )
    func turnsDial(pointX: Double, pointY: Double, expected: Bool) {
        #expect(press.turnsDial(at: CGPoint(x: pointX, y: pointY)) == expected)
    }

    @Test(
        "A touch that ends within 4 pt of its start is a tap",
        arguments: [(201.0, 628.0, true), (205.0, 624.0, true), (205.5, 628.0, false), (201.0, 632.5, false)]
    )
    func isTap(pointX: Double, pointY: Double, expected: Bool) {
        #expect(press.isTap(endingAt: CGPoint(x: pointX, y: pointY)) == expected)
    }
}
