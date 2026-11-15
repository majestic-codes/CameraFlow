//
//  FocusReticle.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The focus square. The location is in unit coordinates of the viewfinder, and the device point is the same point
/// in the camera's coordinates.
struct FocusReticle: Equatable {
    /// What showed the square, which decides how it comes and when it dims.
    enum Kind: Equatable {
        /// A tap, or VoiceOver's lock where no square was shown: the square grows onto the point.
        case tap
        /// A long press: the square fades in larger, without the exposure sun, while the finger holds.
        case press
    }

    let identifier: Int
    let location: CGPoint
    let devicePoint: CGPoint
    let kind: Kind
}
