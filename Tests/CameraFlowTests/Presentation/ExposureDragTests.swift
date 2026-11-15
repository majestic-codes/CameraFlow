//
//  ExposureDragTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@Suite("Exposure drag")
struct ExposureDragTests {
    private let screenRange = -2.0...2.0

    /// Virtual slider positions measured on the stock camera of iOS 27.
    @Test("The virtual slider position of a bias follows the stock table", arguments: [
        (bias: 0.0, position: 0.0),
        (bias: 0.25, position: 26.327),
        (bias: 0.5, position: 54.965),
        (bias: 1.0, position: 120.0),
        (bias: 1.5, position: 196.951),
        (bias: 2.0, position: 288.0),
        (bias: -2.0, position: -288.0),
        (bias: 4.0, position: 852.48)
    ])
    func virtualPosition(bias: Double, position: Double) {
        expectClose(ExposureDrag.virtualPosition(forBias: bias), position, tolerance: 0.001)
        expectClose(ExposureDrag.bias(forVirtualPosition: position), bias, tolerance: 0.0001)
    }

    @Test("The sun moves 9.7 points for the first stop and 23.2 for two, not one to one with the finger")
    func sunHeight() {
        expectClose(ExposureDrag.sunHeight(forBias: 1), 9.69, tolerance: 0.01)
        expectClose(ExposureDrag.sunHeight(forBias: 2), 23.25, tolerance: 0.01)
        #expect(ExposureDrag.sunHeight(forBias: 0) == 0)
        expectClose(ExposureDrag.sunHeight(forBias: 4), 68.833, tolerance: 0.001)
        expectClose(ExposureDrag.sunHeight(forBias: -2), -23.25, tolerance: 0.01)
        expectClose(ExposureDrag.sunValue(forBias: 0), 0.5, tolerance: 0.0001)
        #expect(ExposureDrag.sunValue(forBias: 9) == 1)
    }

    @Test("A drag up brightens and a drag down darkens, 120 points for the first stop", arguments: [
        (translation: CGFloat(-120), start: 0.0, expected: 1.0),
        (translation: CGFloat(120), start: 0.0, expected: -1.0),
        (translation: CGFloat(-288), start: 0.0, expected: 2.0),
        (translation: CGFloat(0), start: -0.7, expected: -0.7),
        (translation: CGFloat(-76), start: 1.0, expected: 1.5)
    ])
    func translation(translation: CGFloat, start: Double, expected: Double) {
        var drag = ExposureDrag(startBias: start, range: screenRange)
        let bias = drag.update(translation: translation)
        expectClose(bias, expected, tolerance: 0.01)
        #expect(drag.bias == bias)
    }

    @Test("Each next stop takes more travel than the one before")
    func slowsDown() {
        var drag = ExposureDrag(startBias: 0, range: screenRange)
        expectClose(drag.update(translation: -120), 1, tolerance: 0.0001)
        #expect(drag.update(translation: -240) < 2)
        expectClose(drag.update(translation: -288), 2, tolerance: 0.0001)
    }

    @Test("The bias stops at both ends of the range", arguments: [
        (translation: CGFloat(-500), expected: 2.0),
        (translation: CGFloat(500), expected: -2.0)
    ])
    func clamped(translation: CGFloat, expected: Double) {
        var drag = ExposureDrag(startBias: 0, range: screenRange)
        expectClose(drag.update(translation: translation), expected, tolerance: 0.0001)
    }

    @Test("A finger that overshoots an end does not store the overshoot")
    func noAccumulation() {
        var drag = ExposureDrag(startBias: 0, range: screenRange)
        _ = drag.update(translation: -400)
        let back = drag.update(translation: -390)
        #expect(back < 2)
        expectClose(ExposureDrag.virtualPosition(forBias: back), 288 - 10, tolerance: 0.0001)
    }

    @Test("A camera range narrower than the screen range ends the drag earlier")
    func narrowRange() {
        var drag = ExposureDrag(startBias: 0, range: -1...1.5)
        expectClose(drag.update(translation: -400), 1.5, tolerance: 0.0001)
        expectClose(drag.update(translation: 400), -1, tolerance: 0.0001)
    }

    @Test("A start bias outside the range is brought inside it")
    func startOutside() {
        let drag = ExposureDrag(startBias: 5, range: screenRange)
        expectClose(drag.bias, 2, tolerance: 0.0001)
    }

    @Test("Moving the finger there and back returns to the start")
    func roundTrip() {
        var drag = ExposureDrag(startBias: 0.3, range: screenRange)
        _ = drag.update(translation: -20)
        let bias = drag.update(translation: 0)
        expectClose(bias, 0.3, tolerance: 0.0001)
    }

    @Test("A drag that begins with no travel, and then moves fast, follows the finger")
    func fastDragFromNoTravel() {
        var drag = ExposureDrag(startBias: 0, range: screenRange)
        #expect(drag.update(translation: 0) == 0)
        let steps: [CGFloat] = [-1.3, -2.7, -5.3, -10.7, -21.3, -28.7]
        let biases = steps.map { drag.update(translation: $0) }
        #expect(biases == biases.sorted())
        expectClose(ExposureDrag.virtualPosition(forBias: drag.bias), 28.7, tolerance: 0.0001)
    }
}
