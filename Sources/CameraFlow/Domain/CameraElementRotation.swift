//
//  CameraElementRotation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The turn of the elements that stay upright as the phone rotates. The angle runs on without wrapping and every
/// change takes the shortest way, so an animation of it never spins the long way round.
struct CameraElementRotation: Sendable, Equatable {
    let orientation: CameraOrientation
    /// Clockwise degrees, always `orientation.elementAngle` plus whole turns.
    let degrees: Double

    static let portrait = Self(orientation: .portrait, degrees: 0)

    /// The rotation after the phone turned to another quarter. A half turn goes clockwise.
    func turned(to newOrientation: CameraOrientation) -> Self {
        let difference = newOrientation.elementAngle - orientation.elementAngle
        var step = difference.truncatingRemainder(dividingBy: 360)
        if step > 180 {
            step -= 360
        } else if step <= -180 {
            step += 360
        }
        return Self(orientation: newOrientation, degrees: degrees + step)
    }

    /// The turn of a block that only flips upside down and stays put in landscape: a whole number of half turns
    /// that follows `degrees`.
    var halfTurnDegrees: Double {
        switch orientation {
        case .portrait, .upsideDown: degrees
        case .landscapeLeft, .landscapeRight: degrees - orientation.elementAngle
        }
    }
}
