//
//  ExposureDrag.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// A vertical drag that changes the exposure bias after a tap on the viewfinder.
///
/// The stock camera does not turn finger travel into stops one to one. The finger moves a virtual slider, and the
/// bias is the logarithm of its position, so the first stop takes 120 points of travel and each next one takes more
/// (exponent 1.4, measured on the stock camera of iOS 27). The sun moves along the rail in proportion to the virtual
/// position, not to the finger. A finger that goes past an end of the range leaves the bias there, and the drag turns
/// back at once when the finger does: the travel past the end is not stored.
struct ExposureDrag: Equatable {
    private typealias Metrics = CameraMetrics.FocusReticle

    /// Virtual slider position of a bias: odd, exponential, 120 points at one stop.
    static func virtualPosition(forBias bias: Double) -> Double {
        let scale = Metrics.virtualSliderPointsForFirstStop / (Metrics.virtualSliderBase - 1)
        return scale * (pow(Metrics.virtualSliderBase, abs(bias)) - 1) * (bias < 0 ? -1 : 1)
    }

    /// The bias of a virtual slider position, the inverse of `virtualPosition(forBias:)`.
    static func bias(forVirtualPosition position: Double) -> Double {
        let scale = Metrics.virtualSliderPointsForFirstStop / (Metrics.virtualSliderBase - 1)
        let stops = log(1 + abs(position) / scale) / log(Metrics.virtualSliderBase)
        return position < 0 ? -stops : stops
    }

    /// Virtual position at the end of the rail.
    static var railPosition: Double {
        virtualPosition(forBias: Metrics.railStops)
    }

    /// Where the sun sits along the rail for a bias: 0 at the bottom, 1 at the top, 0.5 at zero bias. The stock
    /// calls this the normalized exposure value.
    static func sunValue(forBias bias: Double) -> Double {
        let value = 0.5 + virtualPosition(forBias: bias) / (2 * railPosition)
        return min(max(value, 0), 1)
    }

    /// How far above the middle of the rail the sun sits at a bias, in points. Negative is below.
    static func sunHeight(forBias bias: Double) -> CGFloat {
        CGFloat(sunValue(forBias: bias) - 0.5) * Metrics.sunTravel
    }

    private(set) var bias: Double
    private let lowestPosition: Double
    private let highestPosition: Double
    private var position: Double
    private var previousTranslation: CGFloat = 0

    init(startBias: Double, range: ClosedRange<Double>) {
        lowestPosition = Self.virtualPosition(forBias: range.lowerBound)
        highestPosition = Self.virtualPosition(forBias: range.upperBound)
        let start = min(max(Self.virtualPosition(forBias: startBias), lowestPosition), highestPosition)
        position = start
        bias = Self.bias(forVirtualPosition: start)
    }

    /// The bias after the finger has moved to `translation` points below where the drag began. Up is brighter.
    mutating func update(translation: CGFloat) -> Double {
        let step = translation - previousTranslation
        previousTranslation = translation
        position = min(max(position - Double(step), lowestPosition), highestPosition)
        bias = Self.bias(forVirtualPosition: position)
        return bias
    }
}
