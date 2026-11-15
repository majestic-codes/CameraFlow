//
//  DualCameraPhotoWriter.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// Writes the copy of a main photo with the circle of the other camera in it, through `OverlayPhotoWriter`, as the
/// copy with a drawing is written: upright, at full size with the metadata of the original or as an output asks for
/// it, encoded once, with the photo's bit depth and auxiliary images, its gain maps at no boost under the circle. The
/// original is only read. A copy that cannot be written fails as a capture.
///
/// The circle's frame fills the circle as the preview does, unmirrored like every photo of the flow, and is drawn over
/// the part of the photo the viewfinder showed the circle over, at the size it showed it at, with its rim and its
/// shadow.
enum DualCameraPhotoWriter {
    /// The label in the name of the copy, such as `photo-dual-1.heic`.
    static let copyLabel = "dual"

    /// What goes into a copy: the frame of the circle's camera and where the viewfinder showed it.
    struct Composition: Sendable {
        let frame: CircleCameraFrame
        let circle: DualCameraCircle
        /// The part of the upright photo the viewfinder framed, nil for all of it.
        let framedRegion: CGRect?
    }

    /// Writes the copy into `directory` and returns where it is. The copy is brought to `output` as it is written,
    /// with the circle drawn at the size of the copy: the default output keeps the photo's size, metadata and type.
    /// Fails with `CameraServiceError.notEnoughStorage` for want of room, and `CameraServiceError.captureFailed`
    /// otherwise.
    @concurrent
    static func writeCopy(
        of photoURL: URL,
        composition: Composition,
        into directory: URL,
        output: CameraFlowOutput = CameraFlowOutput()
    ) async throws -> URL {
        // A frame decoded for a circle is drawn again for every circle no larger: the copy's own comes first.
        var decoded: (side: CGFloat, picture: CGImage)?
        do {
            return try await OverlayPhotoWriter.writeCopy(
                of: photoURL,
                into: directory,
                label: copyLabel,
                output: output
            ) { bitmap, size in
                let square = circleSquare(of: composition, photoSize: size)
                let framePicture: CGImage
                if let decoded, decoded.side >= square.width {
                    framePicture = decoded.picture
                } else {
                    framePicture = try uprightImage(of: composition.frame, side: square.width)
                    decoded = (square.width, framePicture)
                }
                // The bitmap counts rows from the bottom.
                let bitmapSquare = CGRect(
                    x: square.minX,
                    y: size.height - square.maxY,
                    width: square.width,
                    height: square.height
                )
                draw(framePicture, in: bitmapSquare, of: bitmap, circle: composition.circle)
            }
        } catch OverlayCopyFailure.notEnoughStorage {
            throw CameraServiceError.notEnoughStorage
        } catch let failure as OverlayCopyFailure {
            throw CameraServiceError.captureFailed("The copy with the circle cannot be written: \(failure)")
        }
    }

    /// The square of the circle in pixels of the upright photo of the size, with the origin at the top left.
    private static func circleSquare(of composition: Composition, photoSize: CGSize) -> CGRect {
        DualCameraPlacement.circleRectangle(
            region: composition.circle.region,
            quarterTurns: composition.frame.viewfinderQuarterTurns,
            isViewfinderMirrored: composition.frame.isViewfinderMirrored,
            framedRegion: composition.framedRegion,
            photoSize: photoSize
        )
    }

    /// The upright frame, decoded at about the size it is drawn at: its short side about `side`.
    private static func uprightImage(of frame: CircleCameraFrame, side: CGFloat) throws -> CGImage {
        let photo: ImageSourcePhoto
        do throws(ImageSourcePhoto.ReadFailure) {
            photo = try ImageSourcePhoto(data: frame.imageData)
        } catch {
            throw switch error {
            case .unreadableFile: CameraServiceError.captureFailed("The frame of the circle cannot be read")
            case .unreadableImage: CameraServiceError.captureFailed("The frame of the circle has no size")
            }
        }
        let longSide = max(photo.pixelWidth, photo.pixelHeight)
        let shortSide = min(photo.pixelWidth, photo.pixelHeight)
        let neededLongSide = Int((side * CGFloat(longSide) / CGFloat(shortSide)).rounded(.up))
        guard let upright = photo.uprightImage(maximumLongSide: min(max(neededLongSide, 1), longSide)) else {
            throw CameraServiceError.captureFailed("The frame of the circle cannot be decoded")
        }
        return upright
    }

    /// Draws the circle into the bitmap: its shadow, the frame filling it and clipped to it, and its rim.
    private static func draw(
        _ picture: CGImage,
        in square: CGRect,
        of bitmap: CGContext,
        circle: DualCameraCircle
    ) {
        let diameter = square.width
        let shadowColor = CGColor(gray: 0, alpha: circle.shadowOpacity)
        bitmap.saveGState()
        bitmap.setShadow(offset: .zero, blur: diameter * circle.shadowRadiusRatio, color: shadowColor)
        bitmap.setFillColor(CGColor(gray: 0, alpha: 1))
        bitmap.fillEllipse(in: square)
        bitmap.restoreGState()

        bitmap.saveGState()
        bitmap.addEllipse(in: square)
        bitmap.clip()
        bitmap.interpolationQuality = .high
        let pictureSize = CGSize(width: picture.width, height: picture.height)
        bitmap.draw(picture, in: pictureSize.aspectFillRect(in: square))
        bitmap.restoreGState()

        let rimWidth = diameter * circle.rimWidthRatio
        bitmap.saveGState()
        bitmap.setStrokeColor(CGColor(gray: 1, alpha: circle.rimOpacity))
        bitmap.setLineWidth(rimWidth)
        bitmap.strokeEllipse(in: square.insetBy(dx: rimWidth / 2, dy: rimWidth / 2))
        bitmap.restoreGState()
    }
}
