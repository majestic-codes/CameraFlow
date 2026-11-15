//
//  PhotoZoomLayout.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// How a photo of the review lies in its page and zooms there.
struct PhotoZoomLayout: Equatable, Sendable {
    let pageSize: CGSize
    /// The upright size of the photo, in any unit: only its proportions count.
    let photoSize: CGSize

    /// The photo at the scale of one: whole and as large as the page takes it. A photo or a page without an area
    /// has no fitted size.
    var fittedSize: CGSize {
        guard photoSize.width > 0, photoSize.height > 0, pageSize.width > 0, pageSize.height > 0 else {
            return .zero
        }
        let scale = min(pageSize.width / photoSize.width, pageSize.height / photoSize.height)
        return CGSize(width: photoSize.width * scale, height: photoSize.height * scale)
    }

    /// The margins that hold the photo in the middle of the page along the sides where it is smaller than the
    /// page at a zoom scale. A side the photo fills or overflows has none, so the photo pans to its own edges.
    func centeringMargins(atZoomScale zoomScale: CGFloat) -> CGSize {
        let fitted = fittedSize
        return CGSize(
            width: max((pageSize.width - fitted.width * zoomScale) / 2, 0),
            height: max((pageSize.height - fitted.height * zoomScale) / 2, 0)
        )
    }

    /// The part of the fitted photo that fills the page after a double tap at a point of the fitted photo.
    func doubleTapTarget(around point: CGPoint) -> CGRect {
        let scale = FlowMetrics.PhotoZoom.doubleTapScale
        let size = CGSize(width: pageSize.width / scale, height: pageSize.height / scale)
        return CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
    }
}
