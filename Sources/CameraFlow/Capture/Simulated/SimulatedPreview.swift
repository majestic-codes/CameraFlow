//
//  SimulatedPreview.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import QuartzCore

/// A flat colour or a still picture in place of the camera's picture. The simulated camera has no coordinates of
/// its own, so a point of the layer stays as it is.
@MainActor
final class SimulatedPreview: CameraPreview {
    let layer = CALayer()

    init(color: CGColor) {
        layer.contentsGravity = .resizeAspectFill
        layer.magnificationFilter = .nearest
        layer.masksToBounds = true
        show(color: color)
    }

    func show(color: CGColor) {
        layer.contents = nil
        layer.backgroundColor = color
    }

    /// Shows a picture that fills the layer as a preview fills its view, its pixels kept sharp.
    func show(picture: CGImage) {
        layer.contents = picture
    }

    func devicePoint(atLayerPoint point: CGPoint) -> CGPoint? {
        point
    }
}
