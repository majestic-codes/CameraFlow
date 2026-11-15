//
//  DeviceGravity.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// The pull of gravity along the phone's own axes, in units of g. A phone held upright in portrait is pulled
/// towards its bottom edge only, and one lying face up is pulled into its screen only.
struct DeviceGravity: Sendable, Equatable {
    let towardRightEdge: Double
    let towardTopEdge: Double
    let outOfScreen: Double

    /// Gravity on a phone held upright in a quarter.
    static func upright(in orientation: CameraOrientation) -> Self {
        switch orientation {
        case .portrait: Self(towardRightEdge: 0, towardTopEdge: -1, outOfScreen: 0)
        case .landscapeLeft: Self(towardRightEdge: -1, towardTopEdge: 0, outOfScreen: 0)
        case .landscapeRight: Self(towardRightEdge: 1, towardTopEdge: 0, outOfScreen: 0)
        case .upsideDown: Self(towardRightEdge: 0, towardTopEdge: 1, outOfScreen: 0)
        }
    }
}

extension DeviceGravity {
    /// A screen that stands fewer degrees above the horizontal than this lies flat.
    private static let flatScreenElevation = 45.0
    /// A quarter reaches this many degrees to either side of the phone standing upright in it.
    private static let quarterHalfWidth = 45.0
    /// How many degrees past the end of the held quarter the phone turns before the quarter changes, so that a
    /// phone held on the boundary of two quarters does not flicker between them.
    private static let boundaryHysteresis = 5.0

    /// The quarter the phone is held in, given the quarter it was held in before. A phone that lies flat keeps its
    /// quarter, since gravity no longer tells its edges apart.
    func orientation(holding heldOrientation: CameraOrientation) -> CameraOrientation {
        guard screenElevation >= Self.flatScreenElevation else { return heldOrientation }
        guard turn(awayFrom: heldOrientation) > Self.quarterHalfWidth + Self.boundaryHysteresis else {
            return heldOrientation
        }
        return CameraOrientation.allCases.reduce(heldOrientation) { nearest, candidate in
            turn(awayFrom: candidate) < turn(awayFrom: nearest) ? candidate : nearest
        }
    }

    /// How steeply the screen stands, in degrees: 0 lying on either face, 90 upright.
    private var screenElevation: Double {
        let pullAlongScreen = hypot(towardRightEdge, towardTopEdge)
        return Self.degrees(fromRadians: atan2(pullAlongScreen, abs(outOfScreen)))
    }

    /// How far the phone is turned in the plane of its screen from standing upright in a quarter, in degrees from
    /// 0 to 180.
    private func turn(awayFrom orientation: CameraOrientation) -> Double {
        let difference = uprightElementAngle - orientation.elementAngle
        return abs(difference.remainder(dividingBy: 360))
    }

    /// How far an element turns on the portrait screen to point straight up, in degrees clockwise: what
    /// `CameraOrientation.elementAngle` is for a whole quarter.
    private var uprightElementAngle: Double {
        Self.degrees(fromRadians: atan2(-towardRightEdge, -towardTopEdge))
    }

    private static func degrees(fromRadians radians: Double) -> Double {
        radians * 180 / .pi
    }
}
