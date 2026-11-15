//
//  DialTrackingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@Suite("Dial tracking", .timeLimit(.minutes(1)))
struct DialTrackingTests {
    let scale = ZoomScale(range: 0.5...8)
    let center = CGPoint(x: 200, y: 200)
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 110)

    func makeDrag(snapFactors: [CGFloat]) -> DialDrag {
        let surface = DialSurface(scale: scale, center: center, bounds: bounds, snapFactors: snapFactors)
        return DialDrag(surface: surface, radius: 190)
    }

    func drag(
        _ tracker: inout DialTracker,
        zoom: CGFloat,
        degrees: (start: CGFloat, end: CGFloat),
        snapFactors: [CGFloat]
    ) throws -> CGFloat {
        var time: TimeInterval = 0
        let zooms = makeDrag(snapFactors: snapFactors).turn(
            &tracker,
            zoom: zoom,
            from: degrees.start,
            to: degrees.end,
            time: &time
        )
        return try #require(zooms.last)
    }

    @Test("A slow drag turns the scale one to one: left zooms in")
    func followsTheFinger() throws {
        var tracker = DialTracker(point: makeDrag(snapFactors: []).point(degrees: 0), time: 0)
        let zoom = try drag(&tracker, zoom: 1, degrees: (0, -22.5), snapFactors: [])
        expectClose(zoom, 2, tolerance: 0.01)
    }

    @Test("A drag to an angle off the tenths of a degree ends there")
    func anyAngle() throws {
        var tracker = DialTracker(point: makeDrag(snapFactors: []).point(degrees: 0), time: 0)
        let zoom = try drag(&tracker, zoom: 1, degrees: (0, -22.55), snapFactors: [])
        expectClose(zoom, pow(2, 4 * 22.55 / 90), tolerance: 0.01)
    }

    @Test("A snap point holds the zoom for 14 pt of rim, then lets go without a jump")
    func snapping() throws {
        var tracker = DialTracker(point: makeDrag(snapFactors: [2, 4]).point(degrees: 0), time: 0)
        let held = try drag(&tracker, zoom: 1, degrees: (0, -26), snapFactors: [2, 4])
        #expect(held == 2)
        let released = try drag(&tracker, zoom: held, degrees: (-26, -28), snapFactors: [2, 4])
        #expect(released > 2 && released < 2.2)
    }

    @Test("Radial drags do nothing")
    func radialDamping() {
        let radialStart = CGPoint(x: 200, y: 20)
        let radialEnd = CGPoint(x: 200, y: 10)
        #expect(DialTracker.perpendicularityDamping(from: radialStart, to: radialEnd, center: center) == 0)
        let tangentStart = CGPoint(x: 190, y: 10)
        let tangentEnd = CGPoint(x: 210, y: 10)
        #expect(DialTracker.perpendicularityDamping(from: tangentStart, to: tangentEnd, center: center) == 1)
    }

    @Test("Dragging off the dial fades out over 80 pt")
    func distanceDamping() {
        #expect(DialTracker.distanceDamping(CGPoint(x: 100, y: 50), bounds: bounds) == 1)
        expectClose(DialTracker.distanceDamping(CGPoint(x: 100, y: 150), bounds: bounds), 0.5, tolerance: 0.0001)
        #expect(DialTracker.distanceDamping(CGPoint(x: 100, y: 300), bounds: bounds) == 0)
    }

    @Test("Haptics tick on labels and on every integer before the last label")
    func haptics() {
        let wideScale = ZoomScale(range: 0.5...40)
        let labeledFactors: [CGFloat] = [0.5, 1, 2, 4, 8, 40]
        let snapFactors: [CGFloat] = [1, 2, 4, 8]
        var haptics = DialHaptics(
            labeledFactors: labeledFactors,
            snapFactors: snapFactors,
            scale: wideScale,
            radius: 200
        )
        let ticks = [1.5, 2.05, 2.06, 8.5, 9.2, 9.3].map { haptics.update(zoom: $0) }
        #expect(ticks == [false, true, false, true, true, false])
    }

    // MARK: - Speed

    /// The acceleration of a move of `distance` points across the strip in one frame, to a point at a share of its
    /// width.
    private func acceleration(moving distance: CGFloat, toShare share: CGFloat) -> CGFloat {
        let end = CGPoint(x: bounds.minX + bounds.width * share, y: bounds.midY)
        let start = CGPoint(x: end.x - distance, y: end.y)
        return DialTracker.acceleration(from: start, to: end, elapsed: 1.0 / 60, bounds: bounds)
    }

    @Test("A finger that does not move turns the dial as it is")
    func noAcceleration() {
        #expect(acceleration(moving: 0, toShare: 0.5) == 1)
    }

    @Test("A fast finger in the middle of the strip turns the dial up to three times as far")
    func fastFinger() {
        #expect(acceleration(moving: 30, toShare: 0.5) == 3)
        #expect(acceleration(moving: -30, toShare: 0.5) == 3)
        #expect(acceleration(moving: 12, toShare: 0.5) == 1)
        #expect(acceleration(moving: 21, toShare: 0.5) > 1)
        #expect(acceleration(moving: 21, toShare: 0.5) < 3)
    }

    @Test(
        "A finger moving towards a side while near it turns the dial further, on either side",
        arguments: [(4.0, 0.95), (-4.0, 0.05)]
    )
    func nearTheSide(distance: Double, share: Double) {
        expectClose(acceleration(moving: distance, toShare: share), 1 + 5 * 0.875 * 0.875, tolerance: 0.0001)
        #expect(acceleration(moving: -distance, toShare: share) == 1)
    }

    @Test("The same step taken fast turns the zoom further than taken slowly")
    func fastStepTurnsFurther() {
        let drag = makeDrag(snapFactors: [])
        let start = drag.point(degrees: 0)
        let end = drag.point(degrees: -8)
        var slow = DialTracker(point: start, time: 0)
        var fast = DialTracker(point: start, time: 0)
        let slowZoom = slow.move(to: end, time: 1, zoom: 1, on: drag.surface)
        let fastZoom = fast.move(to: end, time: 1.0 / 60, zoom: 1, on: drag.surface)
        #expect(slowZoom > 1)
        #expect(fastZoom > slowZoom)
    }
}
