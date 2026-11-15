//
//  FrameExpectations.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing

/// Checks a frame against a measured one, to a third of a point unless the test says otherwise: the measurements are
/// in thirds.
func expectClose(
    _ frame: CGRect,
    _ expected: CGRect,
    tolerance: CGFloat = 0.34,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let pairs = [
        (frame.minX, expected.minX), (frame.minY, expected.minY),
        (frame.width, expected.width), (frame.height, expected.height)
    ]
    for (value, target) in pairs {
        expectClose(value, target, tolerance: tolerance, "\(frame) is not \(expected)", sourceLocation: sourceLocation)
    }
}
