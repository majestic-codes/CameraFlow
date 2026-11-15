//
//  LensZoomPress.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// A touch on the zoom control from the point where it began: tells a tap from a turn of the dial.
struct LensZoomPress: Equatable, Sendable {
    private typealias Metrics = CameraMetrics.LensRow

    let start: CGPoint

    func turnsDial(at point: CGPoint) -> Bool {
        abs(point.x - start.x) > Metrics.pressSidewaysTravel || start.y - point.y > Metrics.pressUpwardTravel
    }

    func isTap(endingAt point: CGPoint) -> Bool {
        abs(point.x - start.x) <= Metrics.tapTravel && abs(point.y - start.y) <= Metrics.tapTravel
    }
}
