//
//  MarkupSession.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// One opening of the drawing mode: the canvas and the photo it lies over.
struct MarkupSession<Canvas: MarkupCanvas> {
    let photoIdentifier: UUID
    /// The upright picture of the photo the canvas was opened over, whose proportions the canvas has.
    let picture: CGImage
    let canvas: Canvas
}
