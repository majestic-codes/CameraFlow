//
//  DialDrag.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
@testable import CameraFlow

/// A finger that turns the dial on a circle around its centre: angles are in degrees from the top, clockwise, and
/// the finger moves a tenth of a degree a second, slow enough that the dial turns one to one.
struct DialDrag {
    let surface: DialSurface
    let radius: CGFloat

    func point(degrees: CGFloat) -> CGPoint {
        let angle = degrees * .pi / 180
        let center = surface.center
        return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
    }

    /// Turns the tracker from one angle to another in steps of about a tenth of a degree, a second each, and
    /// returns the zoom after every step. The steps are counted from the angles, so any angle ends the drag.
    func turn(
        _ tracker: inout DialTracker,
        zoom: CGFloat,
        from start: CGFloat,
        to end: CGFloat,
        time: inout TimeInterval
    ) -> [CGFloat] {
        let stepCount = max(Int((abs(end - start) * 10).rounded()), 1)
        var zoom = zoom
        return (1...stepCount).map { step in
            let degrees = start + (end - start) * CGFloat(step) / CGFloat(stepCount)
            time += 1
            zoom = tracker.move(to: point(degrees: degrees), time: time, zoom: zoom, on: surface)
            return zoom
        }
    }
}
