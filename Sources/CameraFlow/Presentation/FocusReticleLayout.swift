//
//  FocusReticleLayout.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Where the exposure slider of the focus reticle sits and how its sun and rail are drawn. All numbers are measured
/// on the stock camera of iOS 27, see `CameraMetrics`.
enum FocusReticleLayout {
    private typealias Metrics = CameraMetrics.FocusReticle

    enum Side: Equatable {
        case trailing
        case leading
    }

    /// The slider goes to the left of the square when the sun, with the full reach of its rays, would cross the right
    /// edge of the viewfinder. The stock flips between a reticle centre of 332 and 333 pt on a 402 pt wide preview.
    static func side(reticleCenterX: CGFloat, viewfinderWidth: CGFloat) -> Side {
        let sunCenter = reticleCenterX + sunOffsetFromCenter(on: .trailing)
        return sunCenter + Metrics.sunMaximumExtent > viewfinderWidth ? .leading : .trailing
    }

    /// Signed distance from the centre of the square to the rail.
    static func sunOffsetFromCenter(on side: Side) -> CGFloat {
        let distance = Metrics.side / 2 + Metrics.sliderOffset
        return side == .trailing ? distance : -distance
    }

    /// The shape of the sun at a position on the rail, 0 at the bottom and 1 at the top. The disc, the gap and the
    /// rays grow towards the top, faster below the middle, as measured on the stock camera of iOS 27.
    struct Sun: Equatable {
        let discRadius: CGFloat
        let rayStart: CGFloat
        let rayLength: CGFloat

        var rayEnd: CGFloat {
            rayStart + rayLength
        }

        init(value: Double) {
            let clamped = min(max(value, 0), 1)
            discRadius = Self.interpolate(clamped, 3, 4.5, 5.5)
            let spacing = Self.interpolate(clamped, 2, 3, 3)
            rayLength = Self.interpolate(clamped, 3.5, 5, 6)
            rayStart = discRadius + spacing
        }

        /// Linear between the three stock values at 0, 0.5 and 1.
        private static func interpolate(_ value: Double, _ low: Double, _ middle: Double, _ high: Double) -> CGFloat {
            if value <= 0.5 {
                return CGFloat(low + (middle - low) * value * 2)
            }
            return CGFloat(middle + (high - middle) * (value - 0.5) * 2)
        }
    }

    /// The two pieces of the rail, as vertical ranges measured from the middle of the rail, down is positive. The
    /// rail is broken around the sun: 3 pt of free space above the reach of its rays and 3 pt below the view of the
    /// sun, which is a third of a point larger than the rays and sits that much lower.
    struct Rail: Equatable {
        let upper: ClosedRange<CGFloat>
        let lower: ClosedRange<CGFloat>

        init(sunHeight: CGFloat, sun: Sun) {
            let half = Metrics.railLength / 2
            let sunY = -sunHeight
            let upperEnd = sunY - sun.rayEnd - Metrics.railGap
            let lowerStart = sunY + sun.rayEnd + Metrics.railGap + Metrics.sunFramePadding
            upper = -half...max(-half, upperEnd)
            lower = min(half, lowerStart)...half
        }
    }
}
