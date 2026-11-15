//
//  MarkupCanvasPlacement.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Where a canvas that keeps the size it opened with stands in the bounds of the view it is shown in: scaled by one
/// factor so that the whole canvas fits, in the middle. The canvas has the proportions of the photo under it, and
/// so has the frame the screen gives the view, so the scaled canvas covers the bounds whole.
struct MarkupCanvasPlacement: Equatable {
    let canvasSize: CGSize
    let bounds: CGRect

    /// How many points of the bounds a point of the canvas covers.
    var scale: CGFloat {
        min(bounds.width / canvasSize.width, bounds.height / canvasSize.height)
    }

    /// Where the middle of the canvas lies in the bounds.
    var center: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    /// The transform of the canvas about its middle.
    var transform: CGAffineTransform {
        CGAffineTransform(scaleX: scale, y: scale)
    }
}
