//
//  ZoomAdjustmentTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Zoom as VoiceOver adjusts it")
struct ZoomAdjustmentTests {
    /// A phone with an ultra wide, a main and a 2x lens, whose digital zoom ends at 10x.
    private static let threeLenses = ZoomAdjustment(lensFactors: [0.5, 1, 2], range: 0.5...10)

    @Test("The stops are the lenses, every whole factor and the end of the digital range")
    func stops() {
        #expect(Self.threeLenses.stops == [0.5, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    }

    @Test("A range that ends between whole factors stops at its end too")
    func fractionalEnd() {
        let adjustment = ZoomAdjustment(lensFactors: [1, 5], range: 1...25.5)
        #expect(adjustment.stops.first == 1)
        #expect(adjustment.stops.contains(5))
        #expect(adjustment.stops.suffix(2) == [25, 25.5])
    }

    @Test(
        "A step goes to the neighbouring stop, from a stop and from between two",
        arguments: [
            (ZoomAdjustment.Direction.increment, CGFloat(1), CGFloat(2)),
            (.increment, 2, 3),
            (.increment, 8, 9),
            (.increment, 2.4, 3),
            (.increment, 0.5, 1),
            (.decrement, 2.4, 2),
            (.decrement, 1, 0.5),
            (.decrement, 10, 9)
        ]
    )
    func step(direction: ZoomAdjustment.Direction, zoom: CGFloat, expected: CGFloat) throws {
        let factor = try #require(Self.threeLenses.factor(from: zoom, toward: direction))
        #expect(factor == expected)
    }

    @Test("No step goes past either end of the range")
    func ends() {
        #expect(Self.threeLenses.factor(from: 10, toward: .increment) == nil)
        #expect(Self.threeLenses.factor(from: 0.5, toward: .decrement) == nil)
    }

    @Test("A lens outside the range is no stop, and a camera without zoom has only its one factor")
    func degenerateRanges() {
        #expect(ZoomAdjustment(lensFactors: [0.5, 1], range: 1...1).stops == [1])
        #expect(ZoomAdjustment(lensFactors: [1], range: 1...1).factor(from: 1, toward: .increment) == nil)
    }
}
