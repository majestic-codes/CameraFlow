//
//  CameraScreenLayout+DualCamera.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The frame of the second camera's circle and the notice row that keeps clear of it.
extension CameraScreenLayout {
    /// The front camera's circle in the top trailing corner of the viewfinder, below the flip button where a tall
    /// viewfinder reaches up beside it.
    var dualCameraCircle: CGRect {
        let frame = viewfinder
        let metrics = FlowMetrics.DualCameraCircle.self
        let diameter = (min(frame.width, frame.height) * metrics.diameterPerViewfinderWidth).rounded()
        let top = max(frame.minY + metrics.margin, flip.maxY + metrics.margin)
        return CGRect(x: frame.maxX - metrics.margin - diameter, y: top, width: diameter, height: diameter)
    }

    /// The row of the notice capsule: across the top of the viewfinder, or below the circle while it shows, so the
    /// two never cover each other.
    func notice(isDualCameraCircleShown: Bool) -> CGRect {
        guard isDualCameraCircleShown else { return notice }
        let row = notice
        return CGRect(
            x: row.minX,
            y: dualCameraCircle.maxY + CameraMetrics.Notice.top,
            width: row.width,
            height: row.height
        )
    }

    /// The circle in the terms a capture composites the front frame with, nil while the viewfinder or the circle has
    /// no size, as in a window that is not laid out yet.
    var dualCameraCirclePlacement: DualCameraCircle? {
        let frame = viewfinder
        let circle = dualCameraCircle
        guard frame.width > 0, frame.height > 0, circle.width > 0 else { return nil }
        let metrics = FlowMetrics.DualCameraCircle.self
        return DualCameraCircle(
            region: circle.unitRect(in: frame),
            rimWidthRatio: metrics.rimWidth / circle.width,
            rimOpacity: metrics.rimOpacity,
            shadowRadiusRatio: metrics.shadowRadius / circle.width,
            shadowOpacity: metrics.shadowOpacity
        )
    }
}
