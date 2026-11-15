//
//  MarkupPainter.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// A stored drawing, decoded, that paints itself at any size.
protocol MarkupPainter: Sendable {

    /// Paints the drawing with its canvas stretched over `size`. The context is in Core Graphics' own coordinates:
    /// one unit per pixel, the origin at the bottom left.
    func paint(in context: CGContext, size: CGSize) async throws
}
