//
//  SubPanelRulerScale.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The scale of the exposure ruler: one tick per third of a stop, 20 pt apart.
enum SubPanelRulerScale {
    static let ticksPerStop = 3
    static let tickPitch: CGFloat = 20
    /// The bias of one tick, the step VoiceOver adjusts the exposure by.
    static let tickBias = 1.0 / Double(ticksPerStop)

    private static let fadeStart = 3.0
    private static let fadeSlope = 0.65

    /// Opacity factor of a tick the given number of tick pitches away from the centre mark.
    static func fade(atDistance distance: Double) -> Double {
        max(0, min(1, 1 - (distance - fadeStart) * fadeSlope))
    }

    /// Indices of the ticks from the lower end of the range to the upper one, 0 at no bias.
    static func tickIndices(in range: ClosedRange<Double>) -> ClosedRange<Int> {
        let lowest = Int((range.lowerBound * Double(ticksPerStop)).rounded(.up))
        let highest = Int((range.upperBound * Double(ticksPerStop)).rounded(.down))
        return lowest...max(lowest, highest)
    }

    /// The exposure bias after dragging the ruler by `translation` points from `start`; dragging right lowers it.
    static func bias(from start: Double, translation: CGFloat) -> Double {
        start - Double(translation / tickPitch) / Double(ticksPerStop)
    }
}
