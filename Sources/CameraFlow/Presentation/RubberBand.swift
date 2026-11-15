//
//  RubberBand.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// How far a dragged element gives way past the end of its travel: it follows the pull less and less, and never
/// moves further than the limit, however far the finger goes.
struct RubberBand: Equatable, Sendable {
    /// The most the element gives way.
    let limit: CGFloat
    /// How soon it nears the limit: the higher, the more it follows the finger at first.
    let stiffness: CGFloat

    /// How far the element gives way for `overshoot` points of pull past the end.
    func offset(forOvershoot overshoot: CGFloat) -> CGFloat {
        guard limit > 0, overshoot > 0 else { return 0 }
        return limit * (1 - 1 / (overshoot * stiffness / limit + 1))
    }
}
