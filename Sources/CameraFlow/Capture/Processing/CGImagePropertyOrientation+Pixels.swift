//
//  CGImagePropertyOrientation+Pixels.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import ImageIO

/// How an EXIF orientation turns the stored pixels of a photo upright. The orientation names the sides of the upright
/// picture that the first stored row and the first stored column are.
extension CGImagePropertyOrientation {
    /// Whether the orientation swaps the width and the height of the stored pixels.
    var swapsSides: Bool {
        switch self {
        case .up, .upMirrored, .down, .downMirrored: false
        case .leftMirrored, .right, .rightMirrored, .left: true
        }
    }

    /// The stored pixel an upright pixel shows, in upright pixels of the given size.
    func storedPixel(column: Int, row: Int, uprightWidth: Int, uprightHeight: Int) -> (column: Int, row: Int) {
        let right = uprightWidth - 1
        let bottom = uprightHeight - 1
        return switch self {
        case .up: (column, row)
        case .upMirrored: (right - column, row)
        case .down: (right - column, bottom - row)
        case .downMirrored: (column, bottom - row)
        case .leftMirrored: (row, column)
        case .right: (row, right - column)
        case .rightMirrored: (bottom - row, right - column)
        case .left: (bottom - row, column)
        }
    }

    /// The upright pixel a stored pixel shows, in stored pixels of the given size.
    func uprightPixel(column: Int, row: Int, storedWidth: Int, storedHeight: Int) -> (column: Int, row: Int) {
        let right = storedWidth - 1
        let bottom = storedHeight - 1
        return switch self {
        case .up: (column, row)
        case .upMirrored: (right - column, row)
        case .down: (right - column, bottom - row)
        case .downMirrored: (column, bottom - row)
        case .leftMirrored: (row, column)
        case .right: (bottom - row, column)
        case .rightMirrored: (bottom - row, right - column)
        case .left: (row, right - column)
        }
    }
}
