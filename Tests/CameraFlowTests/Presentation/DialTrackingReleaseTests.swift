//
//  DialTrackingReleaseTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@Suite("Dial tracking: how a snapped value lets go", .timeLimit(.minutes(1)))
struct DialTrackingReleaseTests {
    private let radius: CGFloat = 190
    private let dialDrag = DialDrag(
        surface: DialSurface(
            scale: ZoomScale(range: 0.5...8),
            center: CGPoint(x: 200, y: 200),
            bounds: CGRect(x: 0, y: 0, width: 400, height: 110),
            snapFactors: [2, 4]
        ),
        radius: 190
    )

    /// Turns the dial in steps of a tenth of a degree and returns the zoom after every step.
    private func drag(
        _ tracker: inout DialTracker,
        zoom: CGFloat,
        from start: CGFloat,
        to end: CGFloat,
        time: inout TimeInterval
    ) -> [CGFloat] {
        dialDrag.turn(&tracker, zoom: zoom, from: start, to: end, time: &time)
    }

    /// A tracker snapped at 2 after a drag from 1, with the angle the finger stopped at.
    private func makeSnappedTracker(time: inout TimeInterval) throws -> (tracker: DialTracker, degrees: CGFloat) {
        var tracker = DialTracker(point: dialDrag.point(degrees: 0), time: 0)
        let zooms = drag(&tracker, zoom: 1, from: 0, to: -23.5, time: &time)
        try #require(zooms.last == 2)
        try #require(tracker.snapped == 2)
        return (tracker, -23.5)
    }

    /// The angle 14 pt of rim take at the radius of the drag, in degrees.
    private var holdDegrees: CGFloat {
        14 / radius * 180 / .pi
    }

    @Test("A snapped value lets go backwards after 14 pt of rim too, and the zoom goes down from it")
    func releasesBackwards() throws {
        var time: TimeInterval = 0
        var (tracker, degrees) = try makeSnappedTracker(time: &time)
        let held = drag(&tracker, zoom: 2, from: degrees, to: degrees + holdDegrees - 0.5, time: &time)
        #expect(held.allSatisfy { $0 == 2 })
        #expect(tracker.snapped == 2)
        degrees += holdDegrees - 0.5
        let released = drag(&tracker, zoom: 2, from: degrees, to: degrees + 3, time: &time)
        let last = try #require(released.last)
        #expect(tracker.snapped == nil)
        #expect(last < 2 && last > 1.8)
    }

    @Test("Turning back while the value holds starts the 14 pt again from where the finger turned")
    func turningBackStartsTheHoldAgain() throws {
        var time: TimeInterval = 0
        var (tracker, degrees) = try makeSnappedTracker(time: &time)
        let forward = holdDegrees * 0.5
        _ = drag(&tracker, zoom: 2, from: degrees, to: degrees - forward, time: &time)
        degrees -= forward
        #expect(tracker.snapped == 2)
        // Back past the point the hold began at, by less than 14 pt from the turn: the value still holds.
        let back = holdDegrees * 0.9
        let held = drag(&tracker, zoom: 2, from: degrees, to: degrees + back, time: &time)
        degrees += back
        #expect(held.allSatisfy { $0 == 2 })
        #expect(tracker.snapped == 2)
        let released = drag(&tracker, zoom: 2, from: degrees, to: degrees + holdDegrees * 0.2 + 1, time: &time)
        let last = try #require(released.last)
        #expect(tracker.snapped == nil)
        #expect(last < 2)
    }
}
