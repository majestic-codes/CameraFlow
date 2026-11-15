//
//  ZoomAdjustment.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The zoom as VoiceOver adjusts it: each swipe moves it to the next or the previous stop. The stops are every lens
/// factor, every whole factor and both ends of the range, so the adjustment reaches the whole range the dial and the
/// pinch reach, the digital zoom past the longest lens too.
struct ZoomAdjustment: Equatable, Sendable {
    enum Direction: Equatable, Sendable {
        case increment
        case decrement
    }

    /// The factors a step lands on, in ascending order.
    let stops: [CGFloat]

    /// Two factors closer than this are one stop.
    private static let tolerance: CGFloat = 0.001

    init(lensFactors: [CGFloat], range: ClosedRange<CGFloat>) {
        let lowestWhole = Int(range.lowerBound.rounded(.up))
        let highestWhole = Int(range.upperBound.rounded(.down))
        let wholeFactors = lowestWhole <= highestWhole ? (lowestWhole...highestWhole).map { CGFloat($0) } : []
        let lenses = lensFactors.filter(range.contains)
        let candidates = (lenses + wholeFactors + [range.lowerBound, range.upperBound]).sorted()
        stops = candidates.reduce(into: []) { stops, factor in
            if let last = stops.last, factor - last < Self.tolerance {
                return
            }
            stops.append(factor)
        }
    }

    /// The nearest stop past the zoom in a direction, nil when the zoom is already at the last stop that way.
    func factor(from zoom: CGFloat, toward direction: Direction) -> CGFloat? {
        switch direction {
        case .increment: stops.first { $0 > zoom + Self.tolerance }
        case .decrement: stops.last { $0 < zoom - Self.tolerance }
        }
    }
}
