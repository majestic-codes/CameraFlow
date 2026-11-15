//
//  DialTracking.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// Where the dial sits and what it snaps to while a finger turns it.
struct DialSurface: Equatable, Sendable {
    let scale: ZoomScale
    let center: CGPoint
    let bounds: CGRect
    let snapFactors: [CGFloat]
}

/// Turns finger movement over the dial into zoom, with snapping, damping and acceleration.
struct DialTracker {
    private(set) var snapped: CGFloat?
    private var unsnappingProgress: CGFloat = 0
    private var previousPoint: CGPoint
    private var previousTime: TimeInterval

    private typealias Metrics = CameraMetrics.ZoomDial

    init(point: CGPoint, time: TimeInterval) {
        previousPoint = point
        previousTime = time
    }

    mutating func move(to point: CGPoint, time: TimeInterval, zoom: CGFloat, on surface: DialSurface) -> CGFloat {
        defer {
            previousPoint = point
            previousTime = time
        }
        let center = surface.center
        let previousAngle = Self.angle(of: previousPoint, center: center)
        let angleStep = Self.wrap(Self.angle(of: point, center: center) - previousAngle)
        let elapsed = time - previousTime
        let delta = -angleStep
            * Self.distanceDamping(point, bounds: surface.bounds)
            * Self.perpendicularityDamping(from: previousPoint, to: point, center: center)
            * Self.acceleration(from: previousPoint, to: point, elapsed: elapsed, bounds: surface.bounds)
        let radius = hypot(point.x - center.x, point.y - center.y)
        let threshold = radius > 0 ? Metrics.snapDistance / radius : 0
        let scale = surface.scale
        var target = delta
        if let snapped {
            guard let released = release(delta: delta, threshold: threshold) else { return snapped }
            target = released
        } else if let factor = snap(target: target, threshold: threshold, zoom: zoom, on: surface) {
            return factor
        }
        guard target != 0 else { return zoom }
        return scale.zoom(normalized: scale.normalized(zoom) + Self.wrap(target) / ZoomScale.sweep)
    }

    /// The angle left over once the finger has pulled the dial off a snapped value, or nil while it holds.
    private mutating func release(delta: CGFloat, threshold: CGFloat) -> CGFloat? {
        if delta > 0 && unsnappingProgress < 0 || delta < 0 && unsnappingProgress > 0 {
            unsnappingProgress = 0
        }
        unsnappingProgress += delta
        let overshoot: CGFloat
        if unsnappingProgress > threshold {
            overshoot = unsnappingProgress - threshold
        } else if unsnappingProgress < -threshold {
            overshoot = unsnappingProgress + threshold
        } else {
            return nil
        }
        snapped = nil
        unsnappingProgress = 0
        return overshoot
    }

    private mutating func snap(
        target: CGFloat,
        threshold: CGFloat,
        zoom: CGFloat,
        on surface: DialSurface
    ) -> CGFloat? {
        for factor in surface.snapFactors {
            let angle = surface.scale.angle(of: factor, current: zoom)
            let offset = target - angle
            let reachesForward = angle > 0 && offset >= 0 && offset < threshold
            let reachesBackward = angle < 0 && offset > -threshold && offset <= 0
            if reachesForward || reachesBackward {
                snapped = factor
                unsnappingProgress = offset
                return factor
            }
        }
        return nil
    }

    static func angle(of point: CGPoint, center: CGPoint) -> CGFloat {
        wrap(atan2(point.y - center.y, point.x - center.x) + .pi / 2)
    }

    private static func wrap(_ angle: CGFloat) -> CGFloat {
        if angle > .pi { return angle - 2 * .pi }
        if angle < -.pi { return angle + 2 * .pi }
        return angle
    }

    /// How much a turn counts for a finger at a point: fully on the dial strip, less and less off its edge.
    static func distanceDamping(_ point: CGPoint, bounds: CGRect) -> CGFloat {
        let overshootX = max(bounds.minX - point.x, point.x - bounds.maxX, 0)
        let overshootY = max(bounds.minY - point.y, point.y - bounds.maxY, 0)
        let distance = hypot(overshootX, overshootY)
        return distance > 0 ? max(0, 1 - distance / Metrics.offDialFadeDistance) : 1
    }

    /// How much a movement turns the dial by its direction: fully across the radius, less and less along it.
    static func perpendicularityDamping(from previous: CGPoint, to point: CGPoint, center: CGPoint) -> CGFloat {
        let movement = CGVector(dx: point.x - previous.x, dy: point.y - previous.y)
        let radial = CGVector(dx: point.x - center.x, dy: point.y - center.y)
        let movementLength = hypot(movement.dx, movement.dy)
        let radialLength = hypot(radial.dx, radial.dy)
        guard movementLength > 0, radialLength > 0 else { return 1 }
        let cosine = abs((movement.dx * radial.dx + movement.dy * radial.dy) / movementLength / radialLength)
        let start = Metrics.radialDampingStartCosine
        guard cosine > start else { return 1 }
        return 1 - normalize(cosine, from: start, to: Metrics.radialDampingEndCosine)
    }

    /// How much faster a movement turns the dial: more for a fast finger, and more for a finger that moves towards
    /// a side of the strip while near it.
    static func acceleration(
        from previous: CGPoint,
        to point: CGPoint,
        elapsed: TimeInterval,
        bounds: CGRect
    ) -> CGFloat {
        let velocity = (point.x - previous.x) * Metrics.speedFrameInterval / max(elapsed, Metrics.shortestMoveInterval)
        let offset = point.x - bounds.minX
        let edgeZone = Metrics.edgeZoneShare * bounds.width
        let edge = point.x > previous.x
            ? normalize(offset, from: bounds.width - edgeZone, to: bounds.width)
            : 1 - normalize(offset, from: 0, to: edgeZone)
        let edgeSpeeds = Metrics.edgeSpeeds
        let edgeSpeed = normalize(abs(velocity), from: edgeSpeeds.lowerBound, to: edgeSpeeds.upperBound)
        let edgeAcceleration = Metrics.edgeBoost * edge * edge * edgeSpeed
        let speed = normalize(abs(velocity), from: Metrics.fastSpeeds.lowerBound, to: Metrics.fastSpeeds.upperBound)
        return 1 + Metrics.fastBoost * speed * speed + edgeAcceleration
    }

    /// Where a value stands between two bounds, 0 to 1. Bounds with no room between them, as on a dial that has no
    /// width yet, give 0 below the upper one and 1 from it on.
    private static func normalize(_ value: CGFloat, from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        guard upper > lower else { return value >= upper ? 1 : 0 }
        return min(max((value - lower) / (upper - lower), 0), 1)
    }
}
