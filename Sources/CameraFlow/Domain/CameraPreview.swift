//
//  CameraPreview.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import QuartzCore

/// The camera's picture on screen: the layer that shows it, and the way from a point of that layer to the
/// camera's own coordinates.
@MainActor
protocol CameraPreview: AnyObject {
    var layer: CALayer { get }
    /// The point in the camera's coordinates that a point of the layer shows, nil while the layer shows no camera.
    func devicePoint(atLayerPoint point: CGPoint) -> CGPoint?
}
