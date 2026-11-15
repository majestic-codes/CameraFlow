//
//  PhotoAuxiliaryImage.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO

/// An auxiliary image of a photo (gain map, matte, depth), as ImageIO reads and writes it: a pixel buffer with a
/// description, and metadata of its own.
enum PhotoAuxiliaryImage {
    /// Why an auxiliary image cannot be cropped faithfully.
    enum CropFailure: Error, Equatable, CustomStringConvertible {
        /// Depth and disparity carry calibration in pixel coordinates of the full frame.
        case calibrated(String)
        case unreadablePixels(AuxiliaryPixels.Failure)

        var description: String {
            switch self {
            case let .calibrated(type): "\(type) carries calibration of the full frame"
            case let .unreadablePixels(failure): failure.description
            }
        }
    }

    /// Every auxiliary image type ImageIO knows. Gain maps first: they are what makes a photo HDR.
    static var types: [CFString] {
        PhotoGainMap.types + [
            kCGImageAuxiliaryDataTypePortraitEffectsMatte,
            kCGImageAuxiliaryDataTypeSemanticSegmentationSkinMatte,
            kCGImageAuxiliaryDataTypeSemanticSegmentationHairMatte,
            kCGImageAuxiliaryDataTypeSemanticSegmentationTeethMatte,
            kCGImageAuxiliaryDataTypeSemanticSegmentationGlassesMatte,
            kCGImageAuxiliaryDataTypeSemanticSegmentationSkyMatte,
            kCGImageAuxiliaryDataTypeDepth,
            kCGImageAuxiliaryDataTypeDisparity
        ]
    }

    /// The auxiliary image cut to the region that `rectangle` is of a frame of `frame` stored pixels. The region
    /// is scaled to the auxiliary image's own size, which is usually a fraction of the photo's. The metadata and
    /// the colour space are kept as they are.
    static func crop(
        _ info: [CFString: Any],
        type: CFString,
        to rectangle: CGRect,
        in frame: CGSize
    ) -> Result<[CFString: Any], CropFailure> {
        let typeName = type as String
        if type == kCGImageAuxiliaryDataTypeDepth || type == kCGImageAuxiliaryDataTypeDisparity {
            return .failure(.calibrated(typeName))
        }
        let pixels: AuxiliaryPixels
        do {
            pixels = try AuxiliaryPixels(info: info, type: type)
        } catch {
            return .failure(.unreadablePixels(error))
        }
        let size = CGSize(width: pixels.width, height: pixels.height)
        let region = scaled(rectangle, from: frame, to: size)
        let cropped = pixels.cropped(left: region.left, top: region.top, width: region.width, height: region.height)
        return .success(cropped.replacingPixels(in: info))
    }

    /// The auxiliary image for an upright copy of the photo: turned the way the photo's orientation turns the photo,
    /// each pixel moved whole, then scaled by the copy's scale when it has one byte a pixel, as gain maps and mattes
    /// have. Pixels of any other format, such as depth and disparity, keep their size, which their description
    /// gives. The metadata and the colour space are kept as they are.
    static func upright(
        _ info: [CFString: Any],
        type: CFString,
        orientation: CGImagePropertyOrientation,
        scale: Double
    ) -> Result<[CFString: Any], AuxiliaryPixels.Failure> {
        let pixels: AuxiliaryPixels
        do {
            pixels = try AuxiliaryPixels(info: info, type: type).upright(orientation)
        } catch {
            return .failure(error)
        }
        guard scale != 1, pixels.isOneByte else {
            return .success(pixels.replacingPixels(in: info))
        }
        guard let scaled = pixels.scaled(by: scale) else {
            return .failure(.malformed(type as String))
        }
        return .success(scaled.replacingPixels(in: info))
    }

    private struct PixelRegion {
        let left: Int
        let top: Int
        let width: Int
        let height: Int
    }

    /// The rectangle in the auxiliary image's pixels: the edges are scaled and rounded to the nearest pixel.
    private static func scaled(_ rectangle: CGRect, from frame: CGSize, to size: CGSize) -> PixelRegion {
        let horizontalScale = size.width / frame.width
        let verticalScale = size.height / frame.height
        let left = Int((rectangle.minX * horizontalScale).rounded())
        let right = Int((rectangle.maxX * horizontalScale).rounded())
        let top = Int((rectangle.minY * verticalScale).rounded())
        let bottom = Int((rectangle.maxY * verticalScale).rounded())
        return PixelRegion(left: left, top: top, width: right - left, height: bottom - top)
    }
}
