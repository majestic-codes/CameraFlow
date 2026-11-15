//
//  CaptureFrameRateThrottle.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// How hard the system presses a camera with its heat and its power draw, the levels of its pressure grouped by what
/// the camera does about them.
enum CaptureSystemPressure: Sendable, Equatable {
    /// Nominal or fair: the camera runs as its format does.
    case low
    /// Serious: a lower frame rate puts off the pause to cool down.
    case serious
    /// Critical or shutdown: a lower frame rate is all the more needed, and the pair gives up one camera.
    case critical
}

/// The frame rates a camera runs at under system pressure: as fast as its format runs while the pressure is low, and
/// between 15 and 20 frames a second from the serious level on.
enum CaptureFrameRateThrottle {
    /// The frame rates of a camera under pressure, in frames a second.
    static let throttledRates = 15.0...20.0

    /// The frame rates for a pressure, nil for the format's own: under low pressure, and on a format whose ranges
    /// do not hold the throttled rates.
    static func frameRates(
        under pressure: CaptureSystemPressure,
        supported ranges: [ClosedRange<Double>]
    ) -> ClosedRange<Double>? {
        guard pressure != .low else { return nil }
        let holdsThrottledRates = ranges.contains { range in
            range.contains(throttledRates.lowerBound) && range.contains(throttledRates.upperBound)
        }
        return holdsThrottledRates ? throttledRates : nil
    }
}
