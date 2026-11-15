//
//  UnitGeometryTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Unit coordinates of a frame and the fill of a picture")
struct UnitGeometryTests {
    private let frame = CGRect(x: 20, y: 140, width: 400, height: 300)

    @Test("A rectangle taken to unit coordinates of a frame and back is the rectangle it was")
    func rectangleRoundTrip() {
        let rectangle = CGRect(x: 260, y: 152, width: 132, height: 132)
        let unit = rectangle.unitRect(in: frame)
        expectClose(unit, CGRect(x: 0.6, y: 0.04, width: 0.33, height: 0.44))
        expectClose(unit.scaled(fromUnitTo: frame), rectangle)
        #expect(frame.unitRect(in: frame) == CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    @Test("A point taken to unit coordinates of a frame and back is the point it was")
    func pointRoundTrip() {
        let point = CGPoint(x: 120, y: 365)
        let unit = point.unitPoint(in: frame)
        #expect(unit == CGPoint(x: 0.25, y: 0.75))
        #expect(unit.scaled(fromUnitTo: frame) == point)
    }

    @Test("A picture fills a container in its proportions, centred, and hangs over on one axis only")
    func aspectFill() {
        let container = CGRect(x: 10, y: 20, width: 300, height: 400)
        let filled = CGSize(width: 4032, height: 3024).aspectFillRect(in: container)
        #expect(filled.height == container.height)
        expectClose(filled.width / filled.height, 4.0 / 3.0, tolerance: 0.0001)
        expectClose(filled.midX, container.midX, tolerance: 0.0001)
        expectClose(filled.midY, container.midY, tolerance: 0.0001)
        #expect(filled.contains(container))
    }

    @Test("A picture fills a square by its short side")
    func squareFill() {
        let square = CGRect(x: 100, y: 100, width: 133, height: 133)
        let filled = CGSize(width: 1080, height: 1920).aspectFillRect(in: square)
        expectClose(filled.width, 133, tolerance: 0.0001)
        expectClose(filled.height, 133 * 1920 / 1080, tolerance: 0.0001)
        expectClose(filled.midY, square.midY, tolerance: 0.0001)
    }
}
