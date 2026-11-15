//
//  RelativeOrientationCase.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

@_spi(Testing) @testable import CameraFlow

/// A phone held in one quarter under an interface that stands in another, and how the phone is held as seen from
/// the interface.
struct RelativeOrientationCase: Sendable {
    let held: CameraOrientation
    let interface: CameraOrientation
    let relative: CameraOrientation

    static let all = [
        Self(held: .portrait, interface: .portrait, relative: .portrait),
        Self(held: .landscapeLeft, interface: .portrait, relative: .landscapeLeft),
        Self(held: .landscapeRight, interface: .portrait, relative: .landscapeRight),
        Self(held: .upsideDown, interface: .portrait, relative: .upsideDown),
        Self(held: .landscapeLeft, interface: .landscapeLeft, relative: .portrait),
        Self(held: .landscapeRight, interface: .landscapeRight, relative: .portrait),
        Self(held: .upsideDown, interface: .upsideDown, relative: .portrait),
        Self(held: .portrait, interface: .landscapeLeft, relative: .landscapeRight),
        Self(held: .portrait, interface: .landscapeRight, relative: .landscapeLeft),
        Self(held: .upsideDown, interface: .landscapeLeft, relative: .landscapeLeft),
        Self(held: .landscapeRight, interface: .landscapeLeft, relative: .upsideDown),
        Self(held: .portrait, interface: .upsideDown, relative: .upsideDown)
    ]
}
