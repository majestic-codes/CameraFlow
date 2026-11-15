//
//  ZoomScaleTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@Suite("Zoom dial scale")
struct ZoomScaleTests {
    let scale = ZoomScale(range: 0.5...8)

    @Test("Matches the system dial", arguments: [(0.7, 0.1214), (1, 0.25), (1.5, 0.3962), (3, 0.6462), (6, 0.8962)])
    func normalized(zoom: Double, expected: Double) {
        expectClose(scale.normalized(zoom), expected, tolerance: 0.0005)
    }

    @Test("Angles are offsets from the needle")
    func angle() {
        expectClose(scale.angle(of: 4, current: 1), .pi / 4, tolerance: 0.0001)
        expectClose(scale.angle(of: 0.5, current: 1), -0.3927, tolerance: 0.0001)
    }

    @Test("A scale of one factor puts every zoom at its start")
    func degenerateScale() {
        let scale = ZoomScale(range: 2...2)
        #expect(scale.normalized(2) == 0)
        #expect(scale.normalized(5) == 0)
        #expect(scale.angle(of: 5, current: 2) == 0)
        #expect(scale.clamped(5) == 2)
    }
}
