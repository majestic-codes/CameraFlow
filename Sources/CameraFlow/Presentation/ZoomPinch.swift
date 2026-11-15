//
//  ZoomPinch.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// A pinch on the viewfinder from the zoom it began at: the zoom is that factor times how far the fingers have
/// spread, kept inside the range of the camera. It holds on to no lens, as the stock camera's pinch does not.
struct ZoomPinch: Equatable, Sendable {
    let startFactor: CGFloat

    /// The zoom at a magnification, which is 1 where the pinch began, 2 for fingers twice as far apart.
    func factor(atMagnification magnification: CGFloat, on scale: ZoomScale) -> CGFloat {
        scale.clamped(startFactor * magnification)
    }
}
