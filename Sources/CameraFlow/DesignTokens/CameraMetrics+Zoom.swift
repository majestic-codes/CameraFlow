//
//  CameraMetrics+Zoom.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// How the lens row takes a press: how far a finger moves before the press turns the dial, and before it stops
/// being a tap.
extension CameraMetrics.LensRow {
    /// Sideways travel from which a press on the lens row turns the dial.
    static let pressSidewaysTravel: CGFloat = 15
    /// Upward travel from which a press on the lens row turns the dial.
    static let pressUpwardTravel: CGFloat = 13
    /// Travel on either axis up to which a touch on the open dial is a tap.
    static let tapTravel: CGFloat = 4
}

/// The timing of the dial and how it turns under a finger.
extension CameraMetrics.ZoomDial {
    /// How long a press on the lens row lasts before it opens the dial.
    static let openDelay = Duration.milliseconds(230)
    /// How long the dial stays open after the finger has lifted.
    static let closeDelay = Duration.milliseconds(1500)

    /// Rim distance a snapped value holds before it lets go.
    static let snapDistance: CGFloat = 14
    /// Distance past the edge of the dial strip over which a finger's turn fades to nothing.
    static let offDialFadeDistance: CGFloat = 80
    /// The cosine of the angle between a finger's movement and the radius from which the turn starts to fade: a
    /// movement closer to the radius than 45 degrees turns the dial less.
    static let radialDampingStartCosine: CGFloat = 0.707
    /// The cosine from which the movement, almost along the radius, turns the dial no more.
    static let radialDampingEndCosine: CGFloat = 0.92

    /// The frame interval a finger's speed is counted in, in seconds: the speed is in points per frame.
    static let speedFrameInterval = 1.0 / 60
    /// The shortest time between two moves the speed is counted over, in seconds.
    static let shortestMoveInterval = 1.0 / 120
    /// The share of the strip's width along each side where a finger moving towards that side turns faster.
    static let edgeZoneShare: CGFloat = 0.4
    /// The speeds, in points per frame, over which the turn near a side grows to its full boost.
    static let edgeSpeeds: ClosedRange<CGFloat> = 2...4
    /// How much a finger at a side and at speed turns the dial more, on top of a slow one.
    static let edgeBoost: CGFloat = 5
    /// The speeds, in points per frame, over which a fast finger's turn grows to its full boost.
    static let fastSpeeds: ClosedRange<CGFloat> = 12...30
    /// How much a fast finger turns the dial more, on top of a slow one.
    static let fastBoost: CGFloat = 2

    /// Ticks of the ring for every whole factor, one every tenth.
    static let ticksPerFactor = 10
}

/// How the face of the dial is drawn: its ticks, how its labels show and the gap in its ticks around the needle.
extension CameraMetrics.ZoomDial {
    /// The opacity of a tick of a tenth: this much at the start of the range, less by `minorTickOpacityFall` at
    /// its end.
    static let minorTickOpacity = 0.3
    static let minorTickOpacityFall = 0.2
    /// The opacity of a tick of a whole factor. A tick of a lens or a mark is opaque.
    static let wholeTickOpacity = 0.93
    /// The line width of a tick of a lens or a mark, and of every other tick.
    static let lensTickWidth: CGFloat = 1
    static let tickWidth: CGFloat = 2.0 / 3.0

    /// The sideways distances from the needle over which a label grows from nothing to its whole size as it moves
    /// away from the current value.
    static let labelPresenceDistances: ClosedRange<CGFloat> = 5.75...28.75
    /// The share of the smallest gap between two labels over which a focal length fades as its lens nears the
    /// needle.
    static let focalLengthFadeReach: CGFloat = 2.0 / 3.0
    /// Labels closer than this angle, in radians, to the label whose lens nears the needle fade their focal
    /// lengths with it.
    static let focalLengthNeighbourAngle: CGFloat = 0.2

    /// The gap in the ticks around the needle, from its centre line and the top of the dial: the mouth above the
    /// ticks, the throat it narrows to, the control points of the curve between them, and how far the throat
    /// reaches below the inner ends of the ticks.
    static let notchMouth = CGSize(width: 14.64, height: 3.67)
    static let notchThroat = CGSize(width: 1.65, height: 21.27)
    static let notchUpperControl = CGSize(width: 2.47, height: 8.69)
    static let notchLowerControl = CGSize(width: 5.33, height: 17.48)
    static let notchDepthBelowTicks: CGFloat = 1.5
}
