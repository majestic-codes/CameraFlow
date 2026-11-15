//
//  ModeSwitchTracking.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// How the thumb of the mode switch follows a finger: where it is under a drag, where it settles when the finger
/// lets go, and how far it stretches. Positions are in progress along the travel, 0 on the shooting and 1 on the
/// review.
struct ModeSwitchTracking: Equatable, Sendable {
    /// The distance in points between the two modes.
    let travel: CGFloat
    /// Whether the review may be reached: it can when it is shown or has photos to show.
    let canReachReview: Bool

    private typealias Metrics = FlowMetrics.ModeSwitch

    // MARK: - Under the finger

    /// Where the thumb is when the finger that took it on `start` has moved `translation` points. It follows the
    /// finger between the ends and gives way, less and less, beyond them.
    func progress(from start: CameraFlowMode, translation: CGFloat) -> CGFloat {
        guard travel > 0 else { return 0 }
        let position = origin(of: start) + translation
        let upper = canReachReview ? travel : 0
        let bounded = if position < 0 {
            -Self.band(-position)
        } else if position > upper {
            upper + Self.band(position - upper)
        } else {
            position
        }
        return bounded / travel
    }

    /// How far the thumb has gone beyond `overshoot` points of pull past an end, never more than the limit.
    static func band(_ overshoot: CGFloat) -> CGFloat {
        let band = RubberBand(limit: Metrics.rubberBandLimit, stiffness: Metrics.rubberBandStiffness)
        return band.offset(forOvershoot: overshoot)
    }

    /// The stretch of the thumb along its way, 0 at rest.
    static func stretch(velocity: CGFloat) -> CGFloat {
        min(abs(velocity) / Metrics.stretchSpeed, 1) * Metrics.stretchLimit
    }

    // MARK: - At the release

    /// Whether a touch moved so little, in any direction, that it is a tap. A finger that slides off the switch,
    /// up into the viewfinder as a swipe does, has not tapped the pill it went down on.
    func isTap(translation: CGSize) -> Bool {
        hypot(translation.width, translation.height) < Metrics.tapSlop
    }

    /// The mode the finger asks for when it lets go with `velocity` points per second: the one nearest to where
    /// the thumb would be a moment later, so a short quick flick is enough. The review may be out of reach.
    func proposedMode(from start: CameraFlowMode, translation: CGFloat, velocity: CGFloat) -> CameraFlowMode {
        guard travel > 0 else { return start }
        let projected = origin(of: start) + translation + velocity * Metrics.projectionTime
        return projected > travel / 2 ? .review : .shooting
    }

    /// The mode the thumb settles on when the finger asks for `mode`: the shooting while the review is out of
    /// reach.
    func reachable(_ mode: CameraFlowMode) -> CameraFlowMode {
        mode == .review && !canReachReview ? .shooting : mode
    }

    /// Where the thumb rests on a mode.
    func restingProgress(of mode: CameraFlowMode) -> CGFloat {
        mode == .review ? 1 : 0
    }

    /// The speed the settling starts at, in distances to the target per second, from the speed of the finger.
    func settleVelocity(from progress: CGFloat, to mode: CameraFlowMode, fingerVelocity: CGFloat) -> Double {
        let distance = restingProgress(of: mode) - progress
        guard travel > 0, abs(distance) > Metrics.minimumSettleDistance else { return 0 }
        let relative = Double(fingerVelocity / travel / distance)
        return min(max(relative, -Metrics.settleVelocityLimit), Metrics.settleVelocityLimit)
    }

    private func origin(of mode: CameraFlowMode) -> CGFloat {
        restingProgress(of: mode) * travel
    }
}
