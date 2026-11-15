//
//  FocusReticleLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Focus reticle layout")
struct FocusReticleLayoutTests {

    /// Reticle centres and the side of the slider the stock chose, on a 402 pt wide preview, measured on the stock
    /// camera of iOS 27 in the simulator.
    @Test("The slider flips to the left when the sun would cross the right edge", arguments: [
        (centerX: CGFloat(0), expected: FocusReticleLayout.Side.trailing),
        (centerX: CGFloat(201), expected: .trailing),
        (centerX: CGFloat(330), expected: .trailing),
        (centerX: CGFloat(332), expected: .trailing),
        (centerX: CGFloat(333), expected: .leading),
        (centerX: CGFloat(340), expected: .leading),
        (centerX: CGFloat(402), expected: .leading)
    ])
    func side(centerX: CGFloat, expected: FocusReticleLayout.Side) {
        // The simulator's square is 75 pt and its slider 17.5 pt from it. The rule is the sun reach against the edge.
        let phoneShift = CameraMetrics.FocusReticle.side / 2 + CameraMetrics.FocusReticle.sliderOffset - (37.5 + 17.5)
        #expect(FocusReticleLayout.side(reticleCenterX: centerX - phoneShift, viewfinderWidth: 402) == expected)
    }

    @Test("The sun sits to the right of the square, or to the left when flipped")
    func offset() {
        expectClose(FocusReticleLayout.sunOffsetFromCenter(on: .trailing), 66.167, tolerance: 0.001)
        expectClose(FocusReticleLayout.sunOffsetFromCenter(on: .leading), -66.167, tolerance: 0.001)
    }

    /// The radius of the disc, the length of a ray and the gap between them, measured on the stock camera of iOS 27.
    @Test("The sun grows with its position on the rail", arguments: [
        (value: 0.0, radius: 3.0, start: 5.0, end: 8.5),
        (value: 0.1, radius: 3.3, start: 5.5, end: 9.3),
        (value: 0.3, radius: 3.9, start: 6.5, end: 10.9),
        (value: 0.5, radius: 4.5, start: 7.5, end: 12.5),
        (value: 0.7, radius: 4.9, start: 7.9, end: 13.3),
        (value: 1.0, radius: 5.5, start: 8.5, end: 14.5)
    ])
    func sun(value: Double, radius: Double, start: Double, end: Double) {
        let sun = FocusReticleLayout.Sun(value: value)
        expectClose(sun.discRadius, radius, tolerance: 0.001)
        expectClose(sun.rayStart, start, tolerance: 0.001)
        expectClose(sun.rayEnd, end, tolerance: 0.001)
    }

    @Test("The sun never reaches further than the maximum extent")
    func extent() {
        #expect(FocusReticleLayout.Sun(value: 2).rayEnd == CameraMetrics.FocusReticle.sunMaximumExtent)
        #expect(FocusReticleLayout.Sun(value: -1).discRadius == 3)
    }

    /// Frames of the two parts of the rail at the middle and at the ends, measured on the stock camera of iOS 27.
    @Test("The rail is broken around the sun", arguments: [
        (value: 0.5, upperEnd: -15.5, lowerStart: 15.833),
        (value: 1.0, upperEnd: -86.333, lowerStart: -51.0),
        (value: 0.0, upperEnd: 57.333, lowerStart: 80.667)
    ])
    func rail(value: Double, upperEnd: CGFloat, lowerStart: CGFloat) {
        let height = CGFloat(value - 0.5) * CameraMetrics.FocusReticle.sunTravel
        let rail = FocusReticleLayout.Rail(sunHeight: height, sun: FocusReticleLayout.Sun(value: value))
        #expect(rail.upper.lowerBound == -71.5)
        expectClose(rail.upper.upperBound, max(-71.5, upperEnd), tolerance: 0.01)
        expectClose(rail.lower.lowerBound, min(71.5, lowerStart), tolerance: 0.01)
        #expect(rail.lower.upperBound == 71.5)
    }
}
