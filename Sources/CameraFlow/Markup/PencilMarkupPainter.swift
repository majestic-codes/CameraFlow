//
//  PencilMarkupPainter.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import PencilKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Paints a PencilKit drawing. The strokes are vectors, so they are rendered at the size asked for.
///
/// PencilKit renders into an image of its own, so the canvas is painted band by band, and only the bands the ink
/// reaches: a full-size picture of the ink never exists beside the bitmap it is painted into. PencilKit leaves the
/// first row of a band's picture empty for some origins of the band, so each band is painted from a picture a pixel
/// taller on both sides, clipped to the band: no row of the bitmap goes without ink, and none gets it twice.
struct PencilMarkupPainter: MarkupPainter {
    private let pencilDrawing: PKDrawing
    private let canvas: CGRect

    /// The height of a band in pixels of the painted picture.
    private static let bandPixelHeight: CGFloat = 512

    init(_ drawing: MarkupDrawing) throws {
        pencilDrawing = try drawing.pencilDrawing()
        canvas = CGRect(origin: .zero, size: drawing.canvasSize)
    }

    func paint(in context: CGContext, size: CGSize) throws {
        let pixelsPerPoint = CGSize(width: size.width / canvas.width, height: size.height / canvas.height)
        let bandHeight = Self.bandPixelHeight / pixelsPerPoint.height
        let onePixel = 1 / pixelsPerPoint.height
        let inkBounds = pencilDrawing.bounds
        for top in stride(from: canvas.minY, to: canvas.maxY, by: bandHeight) {
            let band = CGRect(x: canvas.minX, y: top, width: canvas.width, height: min(bandHeight, canvas.maxY - top))
            guard band.intersects(inkBounds) else { continue }
            let padded = band.insetBy(dx: 0, dy: -onePixel).intersection(canvas)
            let bandTarget = Self.target(of: band, in: size, pixelsPerPoint: pixelsPerPoint)
            let target = Self.target(of: padded, in: size, pixelsPerPoint: pixelsPerPoint)
            // PencilKit's pictures are autoreleased, and each has to go before the next one is made.
            let isPainted = autoreleasepool {
                guard let image = image(of: padded, scale: pixelsPerPoint.width) else { return false }
                context.saveGState()
                context.clip(to: bandTarget.integral)
                context.draw(image, in: target)
                context.restoreGState()
                return true
            }
            guard isPainted else {
                throw MarkupFailure.cannotCreateBitmap(width: Int(target.width), height: Int(target.height))
            }
        }
    }

    /// Where a part of the canvas lands in the bitmap. The canvas counts its rows from the top, the bitmap from the
    /// bottom.
    private static func target(of part: CGRect, in size: CGSize, pixelsPerPoint: CGSize) -> CGRect {
        CGRect(
            x: 0,
            y: size.height - part.maxY * pixelsPerPoint.height,
            width: size.width,
            height: part.height * pixelsPerPoint.height
        )
    }

    /// PencilKit's picture of a part of the canvas, in the dark appearance: PencilKit adapts the ink to the
    /// appearance, and dark is the one the drawing was made in.
    private func image(of band: CGRect, scale: CGFloat) -> CGImage? {
        var image: CGImage?
        #if canImport(UIKit)
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            image = pencilDrawing.image(from: band, scale: scale).cgImage
        }
        #else
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            var pixels = CGRect(x: 0, y: 0, width: band.width * scale, height: band.height * scale)
            let picture = pencilDrawing.image(from: band, scale: scale)
            image = picture.cgImage(forProposedRect: &pixels, context: nil, hints: nil)
        }
        #endif
        return image
    }
}
