//
//  ZoomPinchTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Pinch zoom: the factor of a magnification")
struct ZoomPinchTests {
    let scale = ZoomScale(range: 0.5...40)

    @Test(
        "The zoom is the factor the pinch began at times the magnification",
        arguments: [(1, 1, 1), (1, 1.7, 1.7), (2, 1.5, 3), (4, 0.5, 2), (1, 0.6, 0.6), (0.5, 3, 1.5)]
    )
    func multiplies(start: Double, magnification: Double, expected: Double) {
        let pinch = ZoomPinch(startFactor: start)
        let factor = pinch.factor(atMagnification: magnification, on: scale)
        expectClose(factor, expected, tolerance: 0.000_001)
    }

    @Test(
        "The zoom stops at the ends of the range",
        arguments: [(1, 100, 40), (8, 6, 40), (1, 0.1, 0.5), (0.5, 0, 0.5)]
    )
    func clamps(start: Double, magnification: Double, expected: Double) {
        let pinch = ZoomPinch(startFactor: start)
        let factor = pinch.factor(atMagnification: magnification, on: scale)
        #expect(Double(factor) == expected)
    }

    @Test("A pinch that went past an end comes back as soon as the fingers do")
    func turnsBackAtOnce() {
        let pinch = ZoomPinch(startFactor: 20)
        #expect(pinch.factor(atMagnification: 5, on: scale) == 40)
        #expect(pinch.factor(atMagnification: 1.5, on: scale) == 30)
    }

    @Test("A camera with one factor does not zoom")
    func singleFactor() {
        let pinch = ZoomPinch(startFactor: 1)
        #expect(pinch.factor(atMagnification: 3, on: ZoomScale(range: 1...1)) == 1)
    }
}
