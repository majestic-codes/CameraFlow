//
//  NumberExpectations.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing

/// Whether a number is at most `tolerance` away from `expected`. A `CGFloat` passes as a `Double`.
func isClose(_ value: Double, to expected: Double, tolerance: Double) -> Bool {
    abs(value - expected) <= tolerance
}

/// Checks a number against the expected one, to the tolerance: how the tests compare floating-point values. A failure
/// names both numbers.
func expectClose(
    _ value: Double,
    _ expected: Double,
    tolerance: Double,
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let difference = abs(value - expected)
    let numbers = "\(value) is not within \(tolerance) of \(expected)"
    let text = comment.map { "\($0.rawValue): \(numbers)" } ?? numbers
    #expect(difference <= tolerance, Comment(rawValue: text), sourceLocation: sourceLocation)
}
