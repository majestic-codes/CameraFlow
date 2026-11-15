//
//  SimulatedDualPicture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// What a camera of the simulated dual camera, or the simulated front camera alone, sees: a flat colour with a white
/// letter F in the top leading part of its upright picture. The letter reads wrong when the picture is turned or
/// mirrored, so a preview, a photo and a composited copy show at a glance whether they keep the way the camera sees.
struct SimulatedDualPicture {
    let background: CGColor

    static let letterColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    /// The strokes of the letter in the upright picture as taken, in unit coordinates from the top left: the stem,
    /// the top arm and the shorter middle arm.
    static let letter = [
        CGRect(x: 0.2, y: 0.15, width: 0.12, height: 0.55),
        CGRect(x: 0.2, y: 0.15, width: 0.45, height: 0.1),
        CGRect(x: 0.2, y: 0.38, width: 0.3, height: 0.1)
    ]
    /// The front camera's own colour, an orange that no scene of the launch fixtures uses.
    static let frontColor = CGColor(srgbRed: 0.95, green: 0.55, blue: 0.2, alpha: 1)

    private static let previewWidth = 60
    private static let previewHeight = 80

    /// The upright portrait picture of a preview, mirrored the way a selfie preview is when asked.
    func previewImage(isMirrored: Bool) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: Self.previewWidth,
            height: Self.previewHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw CameraServiceError.captureFailed("Cannot create a bitmap for a simulated preview")
        }
        let size = CGSize(width: Self.previewWidth, height: Self.previewHeight)
        fill(context, size: size) { stroke in
            let upright = isMirrored ? Self.mirrored(stroke) : stroke
            // The bitmap counts rows from the bottom.
            return CGRect(
                x: upright.minX * size.width,
                y: (1 - upright.maxY) * size.height,
                width: upright.width * size.width,
                height: upright.height * size.height
            )
        }
        guard let image = context.makeImage() else {
            throw CameraServiceError.captureFailed("Cannot render a simulated preview")
        }
        return image
    }

    /// Draws the picture as a sensor stores it for the portrait orientation tag 6: landscape, the upright top along
    /// the trailing side. The upright picture is the one taken.
    func drawStored(in context: CGContext, width: Int, height: Int) {
        let size = CGSize(width: width, height: height)
        fill(context, size: size) { stroke in
            // An upright column is a stored row counted from the bottom, an upright row a stored column.
            CGRect(
                x: stroke.minY * size.width,
                y: stroke.minX * size.height,
                width: stroke.height * size.width,
                height: stroke.width * size.height
            )
        }
    }

    private func fill(_ context: CGContext, size: CGSize, place: (CGRect) -> CGRect) {
        context.setFillColor(background)
        context.fill(CGRect(origin: .zero, size: size))
        context.setFillColor(Self.letterColor)
        for stroke in Self.letter {
            context.fill(place(stroke))
        }
    }

    private static func mirrored(_ stroke: CGRect) -> CGRect {
        CGRect(x: 1 - stroke.maxX, y: stroke.minY, width: stroke.width, height: stroke.height)
    }
}
