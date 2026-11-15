//
//  ZoomDialGeometryTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Zoom dial geometry")
struct ZoomDialGeometryTests {
    let geometry = ZoomDialGeometry(center: CGPoint(x: 201, y: 758), radius: 222)

    @Test("The needle is straight up and angles run clockwise")
    func point() {
        let top = geometry.point(at: 0, inset: 36)
        expectClose(top.x, 201, tolerance: 0.0001)
        expectClose(top.y, 572, tolerance: 0.0001)
        let right = geometry.point(at: .pi / 2, inset: 22)
        expectClose(right.x, 401, tolerance: 0.0001)
        expectClose(right.y, 758, tolerance: 0.0001)
    }

    @Test(
        "The ring fades toward both ends of the arc, the same on either side",
        arguments: [
            (0.0, 185.0, 1.0),
            (43.0, 210.0, 1.0),
            (45.13, 210.0, 0.92),
            (51.04, 210.0, 0.56),
            (52.3, 185.67, 0.43),
            (59.36, 210.0, 0.04),
            (60.0, 210.0, 0.0),
            (75.0, 210.0, 0.0)
        ]
    )
    func edgeFade(degrees: Double, distance: Double, expected: Double) {
        let angle = degrees * .pi / 180
        let right = geometry.point(at: angle, inset: geometry.radius - distance)
        let left = geometry.point(at: -angle, inset: geometry.radius - distance)
        let visibility = ZoomDialEdgeFade.visibility(at: right, center: geometry.center)
        expectClose(visibility, expected, tolerance: 0.01)
        expectClose(ZoomDialEdgeFade.visibility(at: left, center: geometry.center), visibility, tolerance: 0.0001)
    }

    @Test("The dial is at full strength one band width from the radius where it is gone", arguments: [false, true])
    func fullStrengthPoint(isMirrored: Bool) {
        let point = ZoomDialEdgeFade.fullStrengthPoint(center: geometry.center, isMirrored: isMirrored)
        expectClose(hypot(point.x - geometry.center.x, point.y - geometry.center.y), 58.5, tolerance: 0.0001)
        expectClose(ZoomDialEdgeFade.visibility(at: point, center: geometry.center), 0.5, tolerance: 0.0001)
        #expect((point.x > geometry.center.x) == isMirrored)
    }
}
