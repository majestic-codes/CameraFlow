//
//  ReviewStripLayout.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Frames of the strip of the set and of what scrolls in it: a round tile per photo and the "+" after the last.
/// The tiles run from the left, or from the right in a right-to-left language, in the order of the set.
struct ReviewStripLayout: Equatable, Sendable {
    /// The band the tiles scroll in, in the coordinates of the whole screen: as wide as the controls under the
    /// viewfinder, and as high as the tiles are apart, which leaves room for the ring of the current tile.
    let frame: CGRect
    let isRightToLeft: Bool

    /// The tile at an index of `count` tiles, in the coordinates of the scrolled content. The first tile stands
    /// where the library button of the shooting mode does, or at the other end in a right-to-left language: there the
    /// tiles are placed from the trailing end of `scrolledWidth(tileCount:)`, so a set that does not fill the strip
    /// still starts on the right.
    func tile(at index: Int, of count: Int) -> CGRect {
        let diameter = CameraMetrics.SideButton.diameter
        let sideInset = CameraMetrics.SideButton.sideInset
        let pitch = FlowMetrics.Strip.pitch
        let minY = (frame.height - diameter) / 2
        guard isRightToLeft else {
            return CGRect(x: sideInset + CGFloat(index) * pitch, y: minY, width: diameter, height: diameter)
        }
        let minX = scrolledWidth(tileCount: count) - sideInset - diameter - CGFloat(index) * pitch
        return CGRect(x: minX, y: minY, width: diameter, height: diameter)
    }

    /// The width of the content with this many tiles, the "+" among them: the last tile keeps the distance to the
    /// trailing edge that the first one has to the leading edge.
    func contentWidth(tileCount: Int) -> CGFloat {
        guard tileCount > 0 else { return 0 }
        let diameter = CameraMetrics.SideButton.diameter
        let span = CGFloat(tileCount - 1) * FlowMetrics.Strip.pitch + diameter
        return CameraMetrics.SideButton.sideInset * 2 + span
    }

    /// The width the strip scrolls: the content's own, or in a right-to-left language at least the strip's, so the
    /// tiles that do not fill it stand at its right end. The scroll view lays out narrower content from the left, as
    /// the screen runs left to right.
    func scrolledWidth(tileCount: Int) -> CGFloat {
        let width = contentWidth(tileCount: tileCount)
        guard isRightToLeft, tileCount > 0 else { return width }
        return max(width, frame.width)
    }

    /// The ring around the tile of the current photo, in the coordinates of the tile.
    static var currentRing: CGRect {
        let radius = CameraMetrics.SideButton.diameter / 2
        return CameraScreenLayout.square(FlowMetrics.Strip.currentRingDiameter, center: CGPoint(x: radius, y: radius))
    }

    /// The dot on a photo with a drawing, in the coordinates of the tile.
    static var drawingMark: CGRect {
        CameraScreenLayout.square(FlowMetrics.Strip.drawingMarkDiameter, center: FlowMetrics.Strip.drawingMarkCenter)
    }
}
