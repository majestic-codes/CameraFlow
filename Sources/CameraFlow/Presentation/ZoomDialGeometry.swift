//
//  ZoomDialGeometry.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// Polar geometry of the zoom dial. Angles are radians from the needle, clockwise.
struct ZoomDialGeometry: Equatable, Sendable {
    let center: CGPoint
    let radius: CGFloat

    func point(at angle: CGFloat, inset: CGFloat) -> CGPoint {
        let distance = radius - inset
        return CGPoint(x: center.x + distance * sin(angle), y: center.y - distance * cos(angle))
    }
}

/// One tick of the dial ring.
struct ZoomDialTick: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// A lens or a marked factor: the widest tick.
        case lens
        /// A whole factor.
        case whole
        case minor
    }

    let factor: CGFloat
    let kind: Kind

    /// A tick every tenth of a factor over the whole range. A lens or a mark takes the tick nearest to it, within
    /// half a tick.
    static func ticks(range: ClosedRange<CGFloat>, emphasizedFactors: [CGFloat]) -> [Self] {
        let ticksPerFactor = CameraMetrics.ZoomDial.ticksPerFactor
        let pitch = 1 / CGFloat(ticksPerFactor)
        let lower = Int((range.lowerBound / pitch).rounded())
        let upper = Int((range.upperBound / pitch).rounded())
        guard lower <= upper else { return [] }
        return (lower...upper).map { index in
            let factor = CGFloat(index) * pitch
            let isEmphasized = emphasizedFactors.contains { abs($0 - factor) < pitch / 2 }
            let kind: Kind = isEmphasized ? .lens : index.isMultiple(of: ticksPerFactor) ? .whole : .minor
            return Self(factor: factor, kind: kind)
        }
    }
}

/// How the ring and its labels fade toward both ends of the visible arc: nothing shows from the radius
/// 60 degrees off the needle on, and the dial grows linearly to full strength over a band beside that radius.
enum ZoomDialEdgeFade {
    /// Angle between the needle and the radius on which the dial is gone.
    static let hiddenAngle = CGFloat.pi / 3
    /// Width of the band beside that radius over which the dial fades.
    static let width: CGFloat = 58.5

    /// How much of the dial shows at a point, 0 to 1.
    static func visibility(at point: CGPoint, center: CGPoint) -> CGFloat {
        let sideways = abs(point.x - center.x)
        let distance = sideways * cos(hiddenAngle) + (point.y - center.y) * sin(hiddenAngle)
        return min(max(-distance / width, 0), 1)
    }

    /// The point across the band from the dial centre where the dial reaches full strength, on either side.
    static func fullStrengthPoint(center: CGPoint, isMirrored: Bool) -> CGPoint {
        let direction: CGFloat = isMirrored ? 1 : -1
        return CGPoint(x: center.x + direction * width * cos(hiddenAngle), y: center.y - width * sin(hiddenAngle))
    }
}

/// How the labels of the dial show as they come under the needle: a factor label shrinks and fades into the current
/// value, and the focal length under it fades while a neighbouring one with a lens behind it takes the needle.
enum ZoomDialLabels {
    private typealias Metrics = CameraMetrics.ZoomDial

    /// How much of a factor label shows at an angle of the dial, 0 to 1, by how far it stands sideways from the
    /// needle.
    static func presence(at angle: CGFloat, geometry: ZoomDialGeometry) -> CGFloat {
        let distance = abs(geometry.point(at: angle, inset: Metrics.labelInset).x - geometry.center.x)
        let range = Metrics.labelPresenceDistances
        return min(max((distance - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    /// The opacity of the focal length of each label at these angles of the dial: the focal length of the label
    /// with a lens closest to the needle, and those of the labels beside it, fade as it nears the needle, over a
    /// share of the smallest gap between two labels.
    static func focalLengthOpacities(angles: [CGFloat], hasFocalLength: [Bool]) -> [Double] {
        let gaps = zip(angles.dropFirst(), angles).map { abs($0 - $1) }
        guard let smallestGap = gaps.min(), smallestGap > 0 else { return angles.map { _ in 1 } }
        let reach = smallestGap * Metrics.focalLengthFadeReach
        let withFocalLength = angles.indices.filter { hasFocalLength[$0] }
        guard let closest = withFocalLength.min(by: { abs(angles[$0]) < abs(angles[$1]) }) else {
            return angles.map { _ in 1 }
        }
        let nearness = min(max(1 - abs(angles[closest]) / reach, 0), 1)
        return angles.indices.map { index in
            abs(angles[index] - angles[closest]) < Metrics.focalLengthNeighbourAngle ? Double(1 - nearness) : 1
        }
    }
}
