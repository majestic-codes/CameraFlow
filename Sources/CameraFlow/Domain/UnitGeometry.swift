//
//  UnitGeometry.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Rectangles in unit coordinates of a frame, 0 at its top-left corner and 1 at its far edges, and back. The
/// viewfinder and the photo speak of the circle and of the framed part of a photo in these, so the one conversion
/// keeps the circle where the viewfinder showed it. The frame has an area.
extension CGRect {

    /// This rectangle in unit coordinates of a frame.
    func unitRect(in frame: CGRect) -> CGRect {
        CGRect(
            x: (minX - frame.minX) / frame.width,
            y: (minY - frame.minY) / frame.height,
            width: width / frame.width,
            height: height / frame.height
        )
    }

    /// A rectangle given in unit coordinates of a frame, in the coordinates the frame is in.
    func scaled(fromUnitTo frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + minX * frame.width,
            y: frame.minY + minY * frame.height,
            width: width * frame.width,
            height: height * frame.height
        )
    }
}

/// Points in unit coordinates of a frame, and back.
extension CGPoint {

    /// This point in unit coordinates of a frame.
    func unitPoint(in frame: CGRect) -> CGPoint {
        CGPoint(x: (x - frame.minX) / frame.width, y: (y - frame.minY) / frame.height)
    }

    /// A point given in unit coordinates of a frame, in the coordinates the frame is in.
    func scaled(fromUnitTo frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX + x * frame.width, y: frame.minY + y * frame.height)
    }
}

extension CGSize {

    /// The rectangle a picture of this size fills a container with: in its proportions, as small as covers the
    /// container, and centred, so what hangs over is cut off evenly on both sides. The size has an area.
    func aspectFillRect(in container: CGRect) -> CGRect {
        let scale = max(container.width / width, container.height / height)
        let filled = CGSize(width: width * scale, height: height * scale)
        return CGRect(
            x: container.midX - filled.width / 2,
            y: container.midY - filled.height / 2,
            width: filled.width,
            height: filled.height
        )
    }
}
