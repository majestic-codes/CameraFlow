//
//  PreviewCoverLayout.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The still that covers a camera's picture while the camera behind it changes.
enum PreviewCoverLayout {

    /// The frame of a still of `stillSize` in a container: scaled evenly until it covers the whole container, and
    /// centred, so that what hangs over is cut off evenly on both sides. A still or a container with no area
    /// gets the container's own bounds.
    static func stillFrame(stillSize: CGSize, in container: CGSize) -> CGRect {
        guard stillSize.width > 0, stillSize.height > 0, container.width > 0, container.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        return stillSize.aspectFillRect(in: CGRect(origin: .zero, size: container))
    }
}
