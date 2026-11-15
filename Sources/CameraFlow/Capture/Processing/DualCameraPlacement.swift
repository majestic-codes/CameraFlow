//
//  DualCameraPlacement.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Where the circle of the other camera lands on the upright main photo: over the part of the picture the viewfinder
/// showed it over, at the size it showed it at.
///
/// The viewfinder shows the camera's picture in the portrait of the interface, the front camera's mirrored. The
/// upright photo is that picture turned by the way the phone was held, never mirrored, and it holds the viewfinder's
/// frame either whole or as its framed region.
enum DualCameraPlacement {

    /// The square of the circle in pixels of the upright photo, with the origin at the top left.
    ///
    /// - Parameters:
    ///   - region: the square of the circle in unit coordinates of the viewfinder, origin at the top left.
    ///   - quarterTurns: how many quarter turns clockwise take the viewfinder's picture to the upright photo.
    ///   - isViewfinderMirrored: whether the viewfinder showed the picture mirrored, which puts the circle at the
    ///     mirrored place of the photo.
    ///   - framedRegion: the part of the upright photo the viewfinder framed, in unit coordinates, nil for all of it.
    ///   - photoSize: the size of the upright photo in pixels.
    static func circleRectangle(
        region: CGRect,
        quarterTurns: Int,
        isViewfinderMirrored: Bool,
        framedRegion: CGRect?,
        photoSize: CGSize
    ) -> CGRect {
        let turnedRegion = turned(region, quarterTurns: quarterTurns)
        let placed = isViewfinderMirrored ? mirrored(turnedRegion) : turnedRegion
        let frame = framedRegion ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        let unit = placed.scaled(fromUnitTo: frame)
        let pixels = unit.scaled(fromUnitTo: CGRect(origin: .zero, size: photoSize))
        // The viewfinder and the framed photo share their proportions, so the square stays a square. Rounding of a
        // crop to whole pixels is evened out around the centre.
        let side = min(pixels.width, pixels.height)
        return CGRect(x: pixels.midX - side / 2, y: pixels.midY - side / 2, width: side, height: side)
    }

    /// The quarter turns clockwise from the viewfinder to a photo taken at a capture angle, given the angle that
    /// shows the same camera in the portrait of the interface. Both angles are clockwise degrees of the sensor's
    /// picture, as `AVCaptureConnection.videoRotationAngle` counts them.
    static func quarterTurns(captureAngle: CGFloat, portraitAngle: CGFloat) -> Int {
        let turns = Int(((captureAngle - portraitAngle) / 90).rounded())
        return (turns % 4 + 4) % 4
    }

    /// A rectangle of the unit square after the square is mirrored about its vertical middle line.
    private static func mirrored(_ rectangle: CGRect) -> CGRect {
        CGRect(x: 1 - rectangle.maxX, y: rectangle.minY, width: rectangle.width, height: rectangle.height)
    }

    /// A rectangle of the unit square after the square is turned clockwise by quarter turns.
    static func turned(_ rectangle: CGRect, quarterTurns: Int) -> CGRect {
        let turns = (quarterTurns % 4 + 4) % 4
        var turnedRectangle = rectangle
        for _ in 0..<turns {
            turnedRectangle = CGRect(
                x: 1 - turnedRectangle.maxY,
                y: turnedRectangle.minX,
                width: turnedRectangle.height,
                height: turnedRectangle.width
            )
        }
        return turnedRectangle
    }
}
