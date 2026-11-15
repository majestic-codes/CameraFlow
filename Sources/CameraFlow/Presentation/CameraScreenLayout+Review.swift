//
//  CameraScreenLayout+Review.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Frames of the review mode, which stands where the camera does above the shared bottom bar.
extension CameraScreenLayout {
    /// The photo of the review, in the place of the 4:3 viewfinder whatever the aspect ratio of the camera is.
    var reviewedPhoto: CGRect {
        standardViewfinder
    }

    /// The rectangle a photo of these proportions fills in the review before it is zoomed: the whole photo, as
    /// large as the frame takes it, in the middle of the frame. The canvas of the drawing mode covers exactly it.
    func reviewedPhotoFrame(photoSize: CGSize) -> CGRect {
        let page = reviewedPhoto
        let zoomLayout = PhotoZoomLayout(pageSize: page.size, photoSize: photoSize)
        let margins = zoomLayout.centeringMargins(atZoomScale: 1)
        let origin = CGPoint(x: page.minX + margins.width, y: page.minY + margins.height)
        return CGRect(origin: origin, size: zoomLayout.fittedSize)
    }

    /// The pages of the review: the frame of the photo and, past its trailing edge, the gap that parts two photos
    /// while one page gives way to the next. The pages show within the frame of the photo, so the gap shows only
    /// between two photos, also where the photo does not reach the edge of the screen.
    var reviewPager: CGRect {
        let photo = reviewedPhoto
        let width = photo.width + FlowMetrics.ReviewPager.pageGap
        return CGRect(x: photo.minX, y: photo.minY, width: width, height: photo.height)
    }

    /// The trash in the top leading corner.
    var reviewTrash: CGRect {
        cornerButton(isTrailing: false)
    }

    /// The Markup button in the top trailing corner, where the shooting mode flips the camera.
    var reviewMarkup: CGRect {
        cornerButton(isTrailing: true)
    }

    /// The line of the counter between the two corner buttons. Text centred in it has the baseline of the mock-up.
    var reviewCounter: CGRect {
        let trash = reviewTrash
        return CGRect(x: trash.maxX, y: trash.minY, width: reviewMarkup.minX - trash.maxX, height: trash.height)
    }

    /// The strip of the set, on the line of the buttons beside the shutter and as wide as the controls under the
    /// viewfinder, so that its first tile stands where the library button does on every screen.
    func reviewStrip(isRightToLeft: Bool) -> ReviewStripLayout {
        let height = FlowMetrics.Strip.pitch
        let band = controlsBand
        let strip = CGRect(x: band.minX, y: library.midY - height / 2, width: band.width, height: height)
        return ReviewStripLayout(frame: strip, isRightToLeft: isRightToLeft)
    }
}
